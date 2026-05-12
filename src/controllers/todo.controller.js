const mongoose = require('mongoose');
const Todo = require('../models/todo.model');

function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

async function listTodos(req, res, next) {
  try {
    const todos = await Todo.find().sort({ createdAt: -1 });
    res.json(todos);
  } catch (error) {
    next(error);
  }
}

async function createTodo(req, res, next) {
  try {
    const { title, completed } = req.body;
    const todo = await Todo.create({ title, completed });
    res.status(201).json(todo);
  } catch (error) {
    next(error);
  }
}

async function getTodo(req, res, next) {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'Invalid todo id' });
    }

    const todo = await Todo.findById(req.params.id);
    if (!todo) {
      return res.status(404).json({ message: 'Todo not found' });
    }

    return res.json(todo);
  } catch (error) {
    return next(error);
  }
}

async function updateTodo(req, res, next) {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'Invalid todo id' });
    }

    const updates = {};
    if (Object.prototype.hasOwnProperty.call(req.body, 'title')) {
      updates.title = req.body.title;
    }
    if (Object.prototype.hasOwnProperty.call(req.body, 'completed')) {
      updates.completed = req.body.completed;
    }

    const todo = await Todo.findByIdAndUpdate(req.params.id, updates, {
      new: true,
      runValidators: true
    });

    if (!todo) {
      return res.status(404).json({ message: 'Todo not found' });
    }

    return res.json(todo);
  } catch (error) {
    return next(error);
  }
}

async function deleteTodo(req, res, next) {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ message: 'Invalid todo id' });
    }

    const todo = await Todo.findByIdAndDelete(req.params.id);
    if (!todo) {
      return res.status(404).json({ message: 'Todo not found' });
    }

    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listTodos,
  createTodo,
  getTodo,
  updateTodo,
  deleteTodo
};
