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
  # Поэтому я бы начал с изменения схемы бд таск трекера и оставил бы старую схему данных ивента.
  # Можно добавить в ивент чуть больше метаинфы как в уроке, что бы в последующем сервисы хотя бы могли
  # отличать версии схемы, но в теории конкретно этот ивент можно будет распарсить и понять его версию
  # просто по наличию поля jira_id.
  #
  # Ивент получится примерно таким:
  # {
  #   event_id: ...,
  #   event_version: 1,
  #   event_name: "TaskAdded",
  #   event_time: ...,
  #   producer: "task-tracker"
  #   data: {
  #     ...
  #     title: task.jira_id ? "[#{task.jira_id}] #{task.title}" : "#{task.title}",
  #     ...
  #   }
  # }
  #
  # Для миграции на новую схему данных ивента нам надо:
  # 1. Найти всех консьюмеров этого ивента и заставить их реализовать консьюмер под новую схему данных.
  #   (Не очень понимаю как это делать в больших командах и с большим проектом с кучей сервисов.)
  #   Помимо консьюмера возможно сервисам так же понадобится сделать изменение схемы данных бд для
  #   хранения jira_id отдельно.
  # 2. Сделать продьюсер для новой схемы данных, где помимо title будет еще jira_id.
  #
  # Так же стоит задуматься о том, что если какой-то сервис захочет восстановить/получить актуальное
  # состояние используя наши ивенты, ему надо будет уметь обрабатывать *все* существующие версии
  # схем данных этого ивента.
  #
  # Все что я написал выше уже во многом теряет актуальность, потому что в дальнейшем я добавил
  # и подключил schema-registry отдельным сервисом. 
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
      Karafka.producer.produce_sync(topic: "tasks-stream", payload: encoded_event)

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
      Karafka.producer.produce_sync(topic: "tasks-lifecycle", payload: encoded_event)

      render json: @task, status: :created
    else
      render json: @task.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /tasks/1
  # def update
  #   if current_account.role != "admin"
  #     return render json: { error: "Forbidden" }, status: :forbidden
  #   end

  #   if @task.update(task_params)
  #     event = {
  #       event_name: "TaskUpdated",
  #       data: {
  #         public_id: @task.public_id,
  #         title: @task.title,
  #         description: @task.description
  #       }
  #     }

  #     Karafka.producer.produce_sync(topic: "tasks-stream", payload: event.to_json)

  #     render json: @task
  #   else
  #     render json: @task.errors, status: :unprocessable_entity
  #   end
  # end

  # DELETE /tasks/1
  # def destroy
  #   if current_account.role != "admin"
  #     return render json: { error: "Forbidden" }, status: :forbidden
  #   end

  #   event = {
  #     event_name: "TaskDeleted",
  #     data: {
  #       public_id: @task.public_id
  #     }
  #   }

  #   Karafka.producer.produce_sync(topic: "tasks-stream", payload: event.to_json)

  #   @task.destroy
  # end

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
      Karafka.producer.produce_sync(topic: "tasks-lifecycle", payload: encoded_event)

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
      Karafka.producer.produce_sync(topic: "tasks-lifecycle", payload: encoded_event)
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
