module.exports = 
  repository:
    type: String
    required: true
  createdBy:
    type: Number
    required: true
  secret:
    type:String
    required: true
  created:
    type: Date
    default: Date.now