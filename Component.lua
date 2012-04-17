require "class"

class "ComponentRequest" {
  rtype = 'ALL';
  name = "";
} 

function ComponentRequest:__init(rt, n)
  self.rtype = rt
  self.name = n
end


class "Message" {
  mtype = '';
  sender = {};
  payload = {};
}

function Message:__init(mt, s, p)
  self.mtype = mt
  self.sender = s
  self.payload = p
end

class "RegisteredComponent" {
  component = {};
  callback = {};
  required = false;
  trackMe = false;
}


function RegisteredComponent:__init()
  self.component = {}
  self.callback = {}
  self.required = false
  self.required = false
end


class "Component" {
  ownerId = 0;
  objectManager = {};
  id = 0;
  name = "";
  destroyed = false;
  track = false;
}

idCounter = 0

function Component:__init(n)
  self.name = n
  self.ownerId = -1
  self.destroyed = false
  self.track = false
  self.objectManager = {}
  self.id = idCounter + 1
  idCounter = idCounter + 1
end

function Component:addedToObject()
end


function Component:registerName(s)
  return self.objectManager:registerName(ownerId, s)
end

function Component:getObjectId(n)
  return self.objectManager:getObjectId(n)
end


function Component:addLocalComponent(c)
  self.objectManager:addComponent(self.ownerId, c)
end

function Component:addComponent(objectId, c)
  self.objectManager:addComponent(objectId, c)
end


function Component:createObject()
  return self.objectManager:createObject()
end

function Component:finalizeObject(objectId)
  self.objectManager:finalizeObject(objectId)
end

function Component:destroyObject(objectId)
  self.objectManager:destroyObject(objectId)
end


function Component:requestMessage(msg, callback)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = false
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('MESSAGE', msg)

  self.objectManager:registerGlobalRequest(req, reg)
end

function Component:requireComponent(name, callback)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = true
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('COMPONENT', name)

  self.objectManager:registerLocalRequest(req, reg)
end

function Component:requestComponent(name, callback, isLocal)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = false
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('COMPONENT', name)

  if isLocal then
    self.objectManager:registerLocalRequest(req, reg)
  else
    self.objectManager:registerGlobalRequest(req, reg)
  end
end

function Component:requestAllExistingComponents(name, callback)
  local reg = RegisteredComponent:new()
  reg.callback = callback
  reg.required = false
  reg.component = self
  reg.trackMe = false

  local req = ComponentRequest:new('ALLCOMPONENTS', name)

  self.objectManager:registerGlobalRequest(req, reg)
end

function Component:getMessageRequestId(name)
  return self.objectManager:getMessageRequestId('MESSAGE', name)
end

function Component:getComponents(objectId, name)
  return self.objectManager:getComponents(objectId, name)
end

function Component:sendMessage(msg, payload)
  self.objectManager:sendGlobalMessage(msg, self, payload)
end

function Component:sendMessageByRequestId(requestId, payload)
  self.objectManager:sendGlobalMessageByRequestId(requestId, self, payload)
end

function Component:sendMessageToObject(objectId, msg, payload)
  self.objectManager:sendMessageToObject(msg, self, objectId, payload)
end

function Component:sendMessageToObjectByRequestId(objectId, requestId, payload)
  self.objectManager:sendMessageToObjectByRequestId(requestId, self, objectId, payload) 
end

function Component:sendMessageToObjectByRequestId(objectId, requestId, msgObject)
  self.objectManager:sendMessageObjectToObjectByRequestId(requestId, self, objectId, msgObject)
end

function Component:sendLocalMessage(msg, payload)
  self.objectManager:sendMessageToObject(msg, self, ownerId, payload)
end

function Component:sendLocalMessageByRequestId(requestId, payload)
  self.objectManager:sendMessageToObjectByRequestId(requestId, self, ownerId, payload)
end

function Component:sendLocalMessageObjectByRequestId(requestId, msgObject)
  self.objectManager:sendMessageObjectToObjectByRequestId(requestId, self, msgObject)
end

function Component:processPing(msgObject)
  -- Does nothing by default
end

function Component:trackComponentRequest(name, isLocal)
  local reqId = self.objectManager:getMessageRequestId('COMPONENT', name)
  self.objectManager:trackRequest(reqId, isLocal, self)
end

function Component:trackMessageRequest(msg)
  local reqId = self.objectManager:getMessageRequestId('MESSAGE', name)
  self.objectManager:trackRequest(reqId, false, self)
end

function Component:destroy()
  self.objectManager:destroyComponent(self)
end

function Component:isValid()
  return self.ownerId >= 0 and #self.name > 0 and not self.destroyed
end

function Component:setOwner(objectId)
  self.ownerId = objectId

  self:requestMessage("ping", function(msg) self:processPing(msg) end)
end

function Component:toString()
  return "Not yet implemented!"
end


