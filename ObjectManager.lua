require "class"
require "Object"

class "RequestLock" {
  locked = false;
  pendingLocalRequests = {};
  pendingGlobalRequests = {};
}


function RequestLock:__init()
  self.locked = false
  self.pendingLocalRequests = {}
  self.pendingGlobalRequests = {}
end


class "ObjectManager" {
  requestIdCounter = 0;
  requestToIdMap = {};
  idToRequestMap = {};
  locks = 0;
  requestLocks = {};
  deadObjects = {};
  deadComponents = {};
  idCounter = 0;
  objects = {};
  objectNameToId = {};
  globalRequests = {};
  requiredComponents = {};
  requestsByComponentId = {};
}

function ObjectManager:__init()
  self.requestIdCounter = 0
  self.requestToIdMap = {}
  self.idToRequestMap = {}
  self.locks = 0
  self.requestLocks = {}
  self.deadObjects = {}
  self.deadComponents = {}
  self.idCounter = 0
  self.objects = {}
  self.objectNameToId = {}
  self.globalRequests = {}
  self.requiredComponents = {}
  self.requestsByComponentId = {}
end

function ObjectManager:createObject()
  self.idCounter = self.idCounter + 1
  local obj = Object:new(self.idCounter)

  table.insert(self.objects, obj)

  return obj.id
end

function ObjectManager:addComponent(objectId, component)
  if not self.objects[objectId] then
    error("Failed to add component "..component.name.." to object "..objectId)
  end

  if not component.objectManager then
    error("Component is already part of an ObjectManager. You cannot add a component twice.")
  end

  local obj = self.objects[objectId]

  component.objectManager = self

  component:setOwner(objectId)

  if not obj:addComponent(component) then
    error("Failed to add component "..component.name.." to object "..objectId)
  end

  component:addedToObject()

  local reqId = self:getExistingRequestId('COMPONENT', component.name)
  if not self.globalRequests[reqId] then
    self.globalRequests[reqId] = {}
  end


  if reqId == 1 then return end

  local msg = Message:new('CREATE', component)

  self:activateLock(reqId)

  for i,v in ipairs(self.globalRequests[reqId]) do
    if v.component.id ~= component.id then
      if v.trackMe then
        print(""..objectId.." recieved component "..component.id.." of type "..self.idToRequestMap['COMPONENT'][reqId])
      end
      v.callback(msg)
    end
  end

  obj:sendMessageObjectByRequestId(reqId, msg)

  self:releaseLock(reqId)

end


function ObjectManager:destroyObject(objectId)
  print("Destroy "..objectId)
  if self.locks ~= 0 then
    table.insert(self.deadObjects, objectId)
    return
  end

  if not self.objects[objectId] then
    error("Failed to destroy object "..objectId.." it does not exist")
  end

  local comps = self.objects[objectId]:getComponents()
  for i,v in ipairs(comps) do
    self:destroyComponent(v)
  end

  self.objects[objectId] = nil
end


function ObjectManager:destroyComponent(component)
  if component.destroyed then return end

  if not component:isValid() then
    error("Error destroying component "..component.id.." component is not valid")
  end

  if self.locks ~= 0 then
    table.insert(self.deadComponents, component)
    return
  end

  local reqs = self.requestsByComponentId[component.id]
  for i,v in ipairs(reqs) do
    local reqId = self:getExistingRequestId(v.rtype, v.name)
    assert(reqId ~= 0)

    for j,reg in ipairs(self.globalRequests[reqId]) do
      if reg.component.id == component.id then
        self.globalRequests[reqId][j] = nil
      end
    end
  end

  self.objects[component.ownerId]:removeComponent(component)

  local msg = Message:new('DESTROY', component)

  local reqId = self:getExistingRequestId('COMPONENT', component.name)
  if reqId ~= 0 then
    self:activateLock(reqId)

    for i,reg in ipairs(self.globalRequests[reqId]) do
      reg.callback(msg)
    end

    self:releaseLock(reqId)
  end

  component.destroyed = true
end

function ObjectManager:finalizeObject(objectId)
  if not self.objects[objectId] then
    error("Failed to finalise object "..objectId.." because it doesn't exist!")
    return
  end
  
  self.objects[objectId].finalized = true

  if not self.requiredComponents[objectId] then return end

  local requiredComponents = self.requiredComponents[objectId]
  local destroyObject = false
  for i,req in ipairs(requiredComponents) do
    local comps = self.objects[objectId]:getComponents(req)
    if #comps == 0 then
      destroyObject = true
    end
  end
  if destroyObject then
    self:destroyObject(objectId)
  end
end

function ObjectManager:registerName(objectId, name)
  if self.objectNameToId[name] then
    error("Failed to register name identifier "..name.." for object "..objectId.." because it already exists!")
    return false
  end
  self.objectNameToId[name] = objectId
  return true
end

function ObjectManager:getObjectId(name)
  if not self.objectNameToId[name] then
    error("Failed to acquire object id for unique name identifier "..name.." because it doesn't exist!")
    return 0
  end
  return self.objectNameToId[name]
end

function ObjectManager:registerGlobalRequest(req, reg)
  assert(reg.component:isValid())

  local reqId = self:getMessageRequestId(req.rtype, req.name)

  if not self.globalRequests[reqId] then self.globalRequests[reqId] = {} end

  if req.rtype ~= 'ALLCOMPONENTS' then
    if self.requestLocks[reqId].locked then
      table.insert(self.requestLocks[reqId].pendingGlobalRequests, { req = req, reg = reg })
    end

    table.insert(self.globalRequests[reqId], reg)

    if req.rtype == 'MESSAGE' then
      self.objects[reg.component.ownerId]:registerRequest(reqId, reg)
    end

    if not self.requestsByComponentId[reg.component.id] then 
      self.requestsByComponentId[reg.component.id] = {} 
    end

    table.insert(self.requestsByComponentId[reg.component.id], req)
    local objectId = reg.component.ownerId

    if reg.required and not self.objects[objectId]:isFinalized() then
      table.insert(requiredComponents[objectId], req.name)
    end
  end

  if req.rtype == 'MESSAGE' then return end

  self:activateLock(reqId)

  local msg = Message:new('CREATE', nil)

  for i,v in ipairs(self.objects) do
    local comps = v:getComponents(req.name)
    for i,c in ipairs(comps) do
      if c:isValid() and reg.component.id ~= c.id then
        msg.sender = c
        if reg.trackMe then
          print(""..reg.component.name.." receieved component "..c.name.." of type "..req.name)
        end
        reg.callback(msg)
      end
    end
  end
  self:releaseLock(reqId)
  
end


function ObjectManager:registerLocalRequest(req, reg)
  local reqId = self:getMessageRequestId(req.rtype, req.name)

  if self.requestLocks[reqId].locked then
    table.insert(self.requestLocks[reqId].pendingLocalRequests, { req = req, reg = reg })
  end

  self.objects[reg.component.ownerId]:registerRequest(reqId, reg)

  if req.rtype ~= 'COMPONENT' then return end

  self:activateLock(reqId)

  local msg = Message:new('CREATE', nil)

  local comps = self.objects[reg.component.ownerId]:getComponents(req.name)
  for i,v in ipairs(comps) do
    if v:isValid() and reg.component.id ~= v.id then
      msg.sender = v
      if reg.trackMe then
        print(""..reg.component.name.." received component "..msg.sender.name.." of type "..req.name)
      end
      reg.callback(msg)
    end
  end

  self:releaseLock(reqId)
end

function ObjectManager:getComponents(objectId, name)
  return self.objects[objectId]:getComponents(name)
end

function ObjectManager:sendGlobalMessage(msg, component, payload)
  self:sendGlobalMessageObjectByRequestId(self:getExistingRequestId('MESSAGE', msg), Message:new('MESSAGE', component, payload))
end

function ObjectManager:sendGlobalMessageByRequestId(requestId, component, payload)
  self:sendGlobalMessageObjectByRequestId(requestId, Message:new('MESSAGE', component, payload))
end

function ObjectManager:sendGlobalMessageObjectByRequestId(requestId, msg)
  assert(msg.sender:isValid())

  self:activateLock(requestId)

  for i,v in ipairs(self.globalRequests[requestId]) do
    if v.trackMe then
      print(""..v.component.name.." received message "..self.idToRequestMap['MESSAGE'][requestId].." from "..msg.sender.name)
    end
    v.callback(msg)
  end
  self:releaseLock(requestId)
end

function ObjectManager:sendMessageToObject(msg, component, objectId, payload)
  self.objects[objectId]:sendMessageObjectByRequestId(self:getMessageRequestId('MESSAGE', msg), Message:new('MESSAGE', component, payload))
end

function ObjectManager:sendMessageToObjectByRequestId(requestId, component, objectId, payload)
  self.objects[objectId]:sendMessageObjectByRequestId(requestId, Message:new('MESSAGE', component, payload), objectId)
end

function ObjectManager:sendMessageObjectToObject(name, msg, objectId)
  self.objects[objectId]:sendMessageObjectByRequestId(self:getMessageRequestId('MESSAGE', name), msg)
end

function ObjectManager:sendMessageObjectToObjectByRequestId(requestId, msg, objectId)
  self.objects[objectId]:sendMessageObjectByRequestId(requestId, msg)
end

function ObjectManager:getMessageRequestId(rtype, name)
  if rtype == 'ALLCOMPONENTS' then rtype = 'COMPONENT' end

  if not self.requestToIdMap[rtype] then 
    self.requestToIdMap[rtype] = {}
    self.idToRequestMap[rtype] = {}
  end

  if not self.requestToIdMap[rtype][name] then
    self.requestIdCounter = self.requestIdCounter + 1

    self.requestToIdMap[rtype][name] = self.requestIdCounter
    self.idToRequestMap[rtype][self.requestIdCounter] = name

    self.requestLocks[self.requestIdCounter] = RequestLock:new()

    return self.requestIdCounter
  else
    return self.requestToIdMap[rtype][name]
  end
end

function ObjectManager:trackRequest(requestId, isLocal, component)
end

function ObjectManager:getRequestById(rtype, requestId)
  return self.idToRequestMap[rtype][requestId]
end

function ObjectManager:getExistingRequestId(ctype, name)
  if not self.requestToIdMap[ctype] or not self.requestToIdMap[ctype][name] then
    return 1
  end
  local id = self.requestToIdMap[ctype][name]

  return id
end

function ObjectManager:activateLock(requestId)
  if self.requestLocks[requestId].locked then
    print("Do not request a message or component in a callback function for the same message/component request or a function called by this callback function")
    return
  end

  self.locks = self.locks + 1
  self.requestLocks[requestId].locked = true
end

function ObjectManager:releaseLock(requestId)
  local lock = self.requestLocks[requestId]

  assert(lock.locked)

  lock.locked = false

  self.locks = self.locks - 1

  local pendingGlobal = lock.pendingGlobalRequests
  local pendingLocal = lock.pendingLocalRequests
  lock.pendingGlobalRequests = {}
  lock.pendingLocalRequests = {}

  for k,v in ipairs(pendingGlobal) do
    self:registerGlobalRequest(v.req, v.reg)
  end
  for k,v in ipairs(pendingLocal) do
    self:registerLocalRequest(v.req, v.reg)
  end

  if self.locks == 0 then
    local deadComponents = self.deadComponents
    self.deadComponents = {}

    for k,v in ipairs(deadComponents) do
      self:destroyComponent(v)
    end

    local deadObjects = self.deadObjects
    self.deadObjects = {}
    for k,v in ipairs(deadObjects) do
      self:destroyObject(v)
    end
  end
end

