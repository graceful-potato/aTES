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
        description: @task.description,
        completed_at: @task.completed_at,
        assignee_id: @task.assignee_id,
        fee: @task.fee,
        reward: @task.reward,
        created_at: @task.created_at
      }

      # Stream event
      event = {
        event_name: "TaskCreated",
        data: data
      }

      Karafka.producer.produce_sync(topic: "tasks-stream", payload: event.to_json)

      # Business event
      event = {
        event_name: "TaskAdded",
        data: data
      }

      Karafka.producer.produce_sync(topic: "tasks-lifecycle", payload: event.to_json)

      render json: @task, status: :created
    else
      render json: @task.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /tasks/1
  def update
    if current_account.role != "admin"
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    if @task.update(task_params)
      event = {
        event_name: "TaskUpdated",
        data: {
          public_id: @task.public_id,
          title: @task.title,
          description: @task.description
        }
      }

      Karafka.producer.produce_sync(topic: "tasks-stream", payload: event.to_json)

      render json: @task
    else
      render json: @task.errors, status: :unprocessable_entity
    end
  end

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
    task = current_account.tasks.find(params[:id])

    if task.update(completed_at: Time.current)
      event = {
        event_name: "TaskCompleted",
        data: {
          public_id: task.public_id,
          completed_at: task.completed_at
        }
      }
  
      Karafka.producer.produce_sync(topic: "tasks-lifecycle", payload: event.to_json)

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
    changes = tasks_in_progress.update_all("assignee_id = (SELECT public_id FROM accounts WHERE role='worker' ORDER BY RANDOM() LIMIT 1)")

    if changes > 0
      event = {
        event_name: "TasksShuffled",
        data: tasks_in_progress.map { |task| { public_id: task.public_id, assignee_id: task.assignee_id } }
      }
  
      Karafka.producer.produce_sync(topic: "tasks-lifecycle", payload: event.to_json)

    end

    render json: tasks_in_progress
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description)
  end
end
