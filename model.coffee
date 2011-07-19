mongoose = require 'mongoose'
Schema = mongoose.Schema
ObjectId = Schema.ObjectId

mongoose.model "User", new Schema
  user:
    type: String
    required: true
    unique: true
  password:
    type: String
    required: true

User = module.exports.User = mongoose.model "User"

mongoose.model "Chart", new Schema
  owner:
    type: String
    required: true
    index: true
  title:
    type: String
    required: true

Chart = module.exports.Chart = mongoose.model "Chart"

schema_Dataset = new Schema
  chart:
    type: ObjectId
    required: true
    index: true
  title:
    type: String
    required: true
  unit:
    type: String
    required: true

mongoose.model "Dataset", schema_Dataset
Dataset = module.exports.Dataset = mongoose.model "Dataset"

schema_Point = new Schema
  dataset:
    type: ObjectId
    required: true
    index: true
  stamp:
    type: Date
    required: true
  data:
    type: Number
    required: true
schema_Point.index
  dataset: 1
  stamp: 1

mongoose.model "Point", schema_Point
Point = module.exports.Point = mongoose.model "Point"

