class Api::V1::TasksController < ApplicationController
  before_action :authenticate_account!
  before_action :set_task, only: %i[ update destroy ]

  # GET /tasks
  def index
    if current_account.role.in?(["admin", "manager"])
      @tasks = Task.all
    else
      @tasks = current_account.tasks
    end

    render json: @tasks
  end

  # POST /tasks
  # Представим, что где-то существуют другие сервисы, которые читают наш ивент создания таски.
  # Так как от нас хотят увидеть отдельное поле для указания задачи из жира, будет немного странно
  # дожидаться изменений во всех консьюмерах, перед тем как приступить к выполнению этой таски.
  # Поэтому на мой взгляд миграция на новую схему должна выглядет так:
  # 1. Добавляем nullable поле jira_id в бд таск трекера
  # 2. Меняем код продьюсера что бы в title записывалась строка вида [jira_id] title тем самым для
  #    остальных серисов ничего не меняется.
  #    Ивент получится примерно таким:
  #    {
  #      event_id: ...,
  #      event_version: 1,
  #      event_name: "TaskAdded",
  #      event_time: ...,
  #      producer: "task-tracker"
  #      data: {
  #        ...
  #        title: task.jira_id ? "[#{task.jira_id}] #{task.title}" : "#{task.title}",
  #        ...
  #      }
  #    }
  # 3. Cоздаем новую версию схемы события в которой будет отдельное поле jira_id и уведомляем всех
  #    консьюмеров этого ивента.
  # 4. Консьмеры сами решают как обрабатывать новую схему события и стоит ли им вносить изменения в
  #    схему базы данных. В контексте дз мы добавляем nullable поле jira_id в accounting и analytics
  #    и переписываем консьюмеры, что бы сохранять jira_id в бд как отдельное поле.
  # 5. После того как все консьюмеры будут готовы принимать ивент новой версии мы можем начать его
  #    рассылать, а после того как убедимся что все работает как надо, можно будет удалить продьюсер
  #    старой версии.
  def create
    unless random_worker = Account.workers.order("RANDOM()").first
      return render json: { error: "No workers to assign"}, status: :unprocessable_entity
    end
    
    @task = Task.new(task_params.merge(assignee: random_worker))
    @task.fee = rand(10..20)
    @task.reward = rand(20..40)

    if @task.save
      @task.reload # load public_id from database

      data = {
        public_id: @task.public_id,
        title: @task.title,
        jira_id: @task.jira_id,
        description: @task.description,
        completed_at: @task.completed_at,
        assignee_id: @task.assignee_id,
        fee: @task.fee,
        reward: @task.reward,
        created_at: @task.created_at
      }

      # Stream event
      event = {
        event_id: SecureRandom.uuid,
        event_version: 1,
        event_time: DateTime.current,
        producer: "task-tracker",
        event_name: "TaskCreated",
        data: data
      }

      encoded_event = AVRO.encode(event, schema_name: "tasks_stream.created")
      ProduceEventJob.perform_async(topic: "tasks-stream", payload: encoded_event)

      # Business event
      event = {
        event_id: SecureRandom.uuid,
        event_version: 1,
        event_time: DateTime.current,
        producer: "task-tracker",
        event_name: "TaskAdded",
        data: data
      }

      encoded_event = AVRO.encode(event, schema_name: "tasks_lifecycle.added")
      ProduceEventJob.perform_async(topic: "tasks-lifecycle", payload: encoded_event)

      render json: @task, status: :created
    else
      render json: @task.errors, status: :unprocessable_entity
    end
  end

  def complete
    task = current_account.tasks.in_progress.find(params[:id])

    if task.update(completed_at: Time.current)
      event = {
        event_id: SecureRandom.uuid,
        event_version: 1,
        event_time: DateTime.current,
        producer: "task-tracker",
        event_name: "TaskCompleted",
        data: {
          public_id: task.public_id,
          assignee_id: task.assignee_id,
          reward: task.reward,
          completed_at: task.completed_at
        }
      }

      encoded_event = AVRO.encode(event, schema_name: "tasks_lifecycle.completed")
      ProduceEventJob.perform_async(topic: "tasks-lifecycle", payload: encoded_event)

      render json: task
    else
      render json: task.errors, status: :unprocessable_entity
    end
  end

  def shuffle
    if !current_account.role.in?(["admin", "manager"])
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    tasks_in_progress = Task.in_progress    
    changes = Task.update_all <<~SQL
      assignee_id = sub.assignee_id
      FROM (
        SELECT DISTINCT ON (tasks.public_id) tasks.public_id, accounts.public_id
        FROM tasks
        JOIN accounts ON true
        WHERE tasks.completed_at IS NULL AND accounts.role = 'worker'
        ORDER BY tasks.public_id, RANDOM()
      ) AS sub(task_public_id, assignee_id)
      WHERE tasks.public_id = sub.task_public_id
    SQL

    if changes > 0
      event = {
        event_id: SecureRandom.uuid,
        event_version: 1,
        event_time: DateTime.current,
        producer: "task-tracker",
        event_name: "TasksShuffled",
        data: tasks_in_progress.map do |task|
          {
            public_id: task.public_id,
            assignee_id: task.assignee_id,
            fee: task.fee
          }
        end
      }

      encoded_event = AVRO.encode(event, schema_name: "tasks_lifecycle.shuffled")
      ProduceEventJob.perform_async(topic: "tasks-lifecycle", payload: encoded_event)
    end

    render json: tasks_in_progress
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :jira_id)
  end
end
