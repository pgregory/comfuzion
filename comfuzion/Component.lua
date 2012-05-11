require "comfuzion.middleclass.middleclass"

local Message = require "comfuzion.Message"

local ComponentRequest = class("ComponentRequest")
function ComponentRequest:initialize(rt, n)
  self.rtype = rt
  self.cname = n
end


local RegisteredComponent = class("RegisteredComponent")
function RegisteredComponent:initialize()
  self.component = {}
  self.callback = {}
  self.required = false
  self.required = false
end


local Component = class("Component")
Component.idCounter = 0
function Component:initialize(n)
  self.cname = n
  self.ownerId = -1
  self.destroyed = false
  self.track = false
  self.entityManager = {}
  self.id = Component.idCounter + 1
  Component.idCounter = Component.idCounter + 1
end

function Component:addedToObject()
end


function Component:registerName(s)
  return self.entityManager:registerName(ownerId, s)
end

function Component:getObjectId(n)
  return self.entityManager:getObjectId(n)
end


function Component:addLocalComponent(c)
  self.entityManager:addComponent(self.ownerId, c)
end

function Component:addComponent(entityId, c)
  self.entityManager:addComponent(entityId, c)
end


function Component:createObject()
  return self.entityManager:createObject()
end

function Component:finalizeObject(entityId)
  self.entityManager:finalizeObject(entityId)
end

function Component:destroyObject(entityId)
  self.entityManager:destroyObject(entityId)
end


function Component:requestMessage(msg, callback)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = false
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('MESSAGE', msg)

  self.entityManager:registerGlobalRequest(req, reg)
end

function Component:requireComponent(cname, callback)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = true
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('COMPONENT', cname)

  self.entityManager:registerLocalRequest(req, reg)
end

function Component:requestComponent(cname, callback, isLocal)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = false
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('COMPONENT', cname)

  if isLocal then
    self.entityManager:registerLocalRequest(req, reg)
  else
    self.entityManager:registerGlobalRequest(req, reg)
  end
end

function Component:requestAllExistingComponents(cname, callback)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = false
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('ALLCOMPONENTS', cname)

  self.entityManager:registerGlobalRequest(req, reg)
end

function Component:getMessageRequestId(cname)
  return self.entityManager:getMessageRequestId('MESSAGE', cname)
end

function Component:getComponents(entityId, cname)
  return self.entityManager:getComponents(entityId, cname)
end

function Component:sendMessage(msg, payload)
  self.entityManager:sendGlobalMessage(msg, self, payload)
end

function Component:sendMessageByRequestId(requestId, payload)
  self.entityManager:sendGlobalMessageByRequestId(requestId, self, payload)
end

function Component:sendMessageToEntity(entityId, msg, payload)
  self.entityManager:sendMessageToEntity(msg, self, entityId, payload)
end

function Component:sendMessageToEntityByRequestId(entityId, requestId, payload)
  self.entityManager:sendMessageToEntityByRequestId(requestId, self, entityId, payload) 
end

function Component:sendMessageToEntityByRequestId(entityId, requestId, msgObject)
  self.entityManager:sendMessageObjectToEntityByRequestId(requestId, self, entityId, msgObject)
end

function Component:sendLocalMessage(msg, payload)
  self.entityManager:sendMessageToEntity(msg, self, ownerId, payload)
end

function Component:sendLocalMessageByRequestId(requestId, payload)
  self.entityManager:sendMessageToEntityByRequestId(requestId, self, ownerId, payload)
end

function Component:sendLocalMessageObjectByRequestId(requestId, msgObject)
  self.entityManager:sendMessageObjectToObjectByRequestId(requestId, self, msgObject)
end

function Component:processPing(msgObject)
  -- Does nothing by default
end

function Component:trackComponentRequest(cname, isLocal)
  local reqId = self.entityManager:getMessageRequestId('COMPONENT', cname)
  self.entityManager:trackRequest(reqId, isLocal, self)
end

function Component:trackMessageRequest(msg)
  local reqId = self.entityManager:getMessageRequestId('MESSAGE', cname)
  self.entityManager:trackRequest(reqId, false, self)
end

function Component:destroy()
  self.entityManager:destroyComponent(self)
end

function Component:isValid()
  return self.ownerId >= 0 and #self.cname > 0 and not self.destroyed
end

function Component:setOwner(entityId)
  self.ownerId = entityId

  self:requestMessage("ping", function(msg) self:processPing(msg) end)
end

function Component:toString()
  return "Not yet implemented!"
end

return Component
