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
    type: ObjectId
    required: true
    index: true
  title:
    type: String
    required: true

Chart = module.exports.Chart = mongoose.model "Chart"

schema_Point = new Schema
  chart:
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
  chart: 1
  stamp: 1

mongoose.model "Point", schema_Point
Point = module.exports.Point = mongoose.model "Point"

