module Api
  module V1
    class TodosController < ApplicationController
      before_action :set_todo, only: %i[show update destroy]

      # GET /api/v1/todos
      # GET /api/v1/todos?completed=true
      # GET /api/v1/todos?completed=false
      def index
        @todos = Todo.all

        if params.key?(:completed)
          completed = ActiveModel::Type::Boolean.new.cast(params[:completed])
          @todos = completed ? @todos.completed : @todos.incomplete
        end

        render json: @todos, status: :ok
      end

      # GET /api/v1/todos/:id
      def show
        render json: @todo, status: :ok
      end

      # POST /api/v1/todos
      def create
        @todo = Todo.new(todo_params)

        if @todo.save
          render json: @todo, status: :created, location: api_v1_todo_url(@todo)
        else
          render json: { errors: @todo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/todos/:id
      def update
        if @todo.update(todo_params)
          render json: @todo, status: :ok
        else
          render json: { errors: @todo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/todos/:id
      def destroy
        @todo.destroy
        head :no_content
      end

      private

      def set_todo
        @todo = Todo.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Todo not found" }, status: :not_found
      end

      def todo_params
        params.require(:todo).permit(:title, :completed)
      end
    end
  end
end