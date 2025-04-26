require_relative '../services/gemini_service'
require_relative '../services/notion_service'

class TasksController < ApplicationController
  before_action :set_task, only: [:show, :edit, :update, :destroy, :generate_subtasks, :select_subtasks, :save_selected_subtasks, :export_to_notion]

  def index
    @tasks = Task.all.order(created_at: :desc)
  end

  def show
  end

  def new
    @task = Task.new
  end

  def create
    @task = Task.new(task_params)
    # In a real app, you would set the current user
    # @task.user_id = current_user.id

    if @task.save
      redirect_to generate_subtasks_task_path(@task), notice: 'Task was successfully created. Now let\'s generate some subtasks!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @task.update(task_params)
      redirect_to @task, notice: 'Task was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to tasks_path, notice: 'Task was successfully deleted.'
  end

  # Generate subtasks using Gemini API
  def generate_subtasks
    gemini_service = GeminiService.new
    begin
      subtasks_data = gemini_service.generate_subtasks(@task)

      if subtasks_data.present?
        # Store the generated subtasks in the session temporarily
        session[:generated_subtasks] = subtasks_data
        redirect_to select_subtasks_task_path(@task)
      else
        redirect_to @task, alert: 'Failed to generate subtasks. Please try again.'
      end
    rescue StandardError => e
      redirect_to @task, alert: "Error generating subtasks: #{e.message}"
    end
  end

  # Display generated subtasks for selection
  def select_subtasks
    @generated_subtasks = session[:generated_subtasks] || []
  end

  # Save the subtasks selected by the user
  def save_selected_subtasks
    selected_ids = params[:selected_subtasks] || []

    # Get all generated subtasks from session
    generated_subtasks = session[:generated_subtasks] || []

    if selected_ids.any? && generated_subtasks.any?
      # Save only the selected subtasks
      selected_ids.each do |index|
        subtask_data = generated_subtasks[index.to_i]
        @task.subtasks.create(
          title: subtask_data['title'],
          description: subtask_data['description'],
          status: 'pending'
        )
      end

      # Clear the session
      session.delete(:generated_subtasks)

      if params[:export_to_notion].present?
        redirect_to export_to_notion_task_path(@task)
      else
        redirect_to @task, notice: "#{selected_ids.size} subtasks were saved successfully!"
      end
    else
      redirect_to @task, alert: 'No subtasks were selected or no subtasks were generated.'
    end
  end

  # Export tasks to Notion
  def export_to_notion
    begin
      notion_service = NotionService.new
      result = notion_service.export_task(@task)

      if result[:success]
        redirect_to @task, notice: 'Task and subtasks exported to Notion successfully!'
      else
        redirect_to @task, alert: "Failed to export to Notion: #{result[:error]}"
      end
    rescue StandardError => e
      redirect_to @task, alert: "Error exporting to Notion: #{e.message}"
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :priority, :status)
  end
end
