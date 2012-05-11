require "comfuzion.middleclass.middleclass"
local Entity = require "comfuzion.Entity"
local Message = require "comfuzion.Message"

local RequestLock = class("RequestLock")
function RequestLock:initialize()
  self.locked = false
  self.pendingLocalRequests = {}
  self.pendingGlobalRequests = {}
end


local EntityManager = class("EntityManager")
function EntityManager:initialize()
  self.requestIdCounter = 0
  self.requestToIdMap = {}
  self.idToRequestMap = {}
  self.locks = 0
  self.requestLocks = {}
  self.deadEntities = {}
  self.deadComponents = {}
  self.idCounter = 0
  self.entities = {}
  self.entityNameToId = {}
  self.globalRequests = {}
  self.requiredComponents = {}
  self.requestsByComponentId = {}
end

function EntityManager:createEntity()
  self.idCounter = self.idCounter + 1
  local obj = Entity:new(self.idCounter)

  table.insert(self.entities, obj)

  return obj.id
end

function EntityManager:addComponent(entityId, component)
  if not self.entities[entityId] then
    error("Failed to add component "..component.cname.." to entity "..entityId)
  end

  if not component.entityManager then
    error("Component is already part of an EntityManager. You cannot add a component twice.")
  end

  local obj = self.entities[entityId]

  component.entityManager = self

  component:setOwner(entityId)

  if not obj:addComponent(component) then
    error("Failed to add component "..component.cname.." to entity "..entityId)
  end

  component:addedToEntity()

  local reqId = self:getExistingRequestId('COMPONENT', component.cname)
  if not self.globalRequests[reqId] then
    self.globalRequests[reqId] = {}
  end


  if reqId == 1 then return end

  local msg = Message:new('CREATE', component)

  self:activateLock(reqId)

  for i,v in ipairs(self.globalRequests[reqId]) do
    if v.component.id ~= component.id then
      if v.trackMe then
        print(""..entityId.." recieved component "..component.id.." of type "..self.idToRequestMap['COMPONENT'][reqId])
      end
      v.callback(msg)
    end
  end

  obj:sendMessageObjectByRequestId(reqId, msg)

  self:releaseLock(reqId)

end


function EntityManager:destroyEntity(entityId)
  if self.locks ~= 0 then
    table.insert(self.deadEntities, entityId)
    return
  end

  if not self.entities[entityId] then
    error("Failed to destroy entity "..entityId.." it does not exist")
  end

  local comps = self.entities[entityId]:getComponents()
  for i,v in ipairs(comps) do
    self:destroyComponent(v)
  end

  self.entities[entityId] = nil
end


function EntityManager:destroyComponent(component)
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
    local reqId = self:getExistingRequestId(v.rtype, v.cname)
    assert(reqId ~= 0)

    for j,reg in ipairs(self.globalRequests[reqId]) do
      if reg.component.id == component.id then
        self.globalRequests[reqId][j] = nil
      end
    end
  end

  self.entities[component.ownerId]:removeComponent(component)

  local msg = Message:new('DESTROY', component)

  local reqId = self:getExistingRequestId('COMPONENT', component.cname)
  if reqId ~= 0 then
    self:activateLock(reqId)

    for i,reg in ipairs(self.globalRequests[reqId]) do
      reg.callback(msg)
    end

    self:releaseLock(reqId)
  end

  component.destroyed = true
end

function EntityManager:finalizeEntity(entityId)
  if not self.entities[entityId] then
    error("Failed to finalise entity "..entityId.." because it doesn't exist!")
    return
  end
  
  self.entities[entityId].finalized = true

  if not self.requiredComponents[entityId] then return end

  local requiredComponents = self.requiredComponents[entityId]
  local destroyEntity = false
  for i,req in ipairs(requiredComponents) do
    local comps = self.entities[entityId]:getComponents(req)
    if #comps == 0 then
      destroyEntity = true
    end
  end
  if destroyEntity then
    self:destroyEntity(entityId)
  end
end

function EntityManager:registerName(entityId, name)
  if self.entityNameToId[name] then
    error("Failed to register name identifier "..name.." for entity "..entityId.." because it already exists!")
    return false
  end
  self.entityNameToId[name] = entityId
  return true
end

function EntityManager:getEntityId(name)
  if not self.entityNameToId[name] then
    error("Failed to acquire entity id for unique name identifier "..name.." because it doesn't exist!")
    return 0
  end
  return self.entityNameToId[name]
end

function EntityManager:registerGlobalRequest(req, reg)
  assert(reg.component:isValid())

  local reqId = self:getMessageRequestId(req.rtype, req.cname)

  if not self.globalRequests[reqId] then self.globalRequests[reqId] = {} end

  if req.rtype ~= 'ALLCOMPONENTS' then
    if self.requestLocks[reqId].locked then
      table.insert(self.requestLocks[reqId].pendingGlobalRequests, { req = req, reg = reg })
    end

    table.insert(self.globalRequests[reqId], reg)

    if req.rtype == 'MESSAGE' then
      self.entities[reg.component.ownerId]:registerRequest(reqId, reg)
    end

    if not self.requestsByComponentId[reg.component.id] then 
      self.requestsByComponentId[reg.component.id] = {} 
    end

    table.insert(self.requestsByComponentId[reg.component.id], req)
    local entityId = reg.component.ownerId

    if reg.required and not self.entities[entityId]:isFinalized() then
      table.insert(requiredComponents[entityId], req.cname)
    end
  end

  if req.rtype == 'MESSAGE' then return end

  self:activateLock(reqId)

  local msg = Message:new('CREATE', nil)

  for i,v in ipairs(self.entities) do
    local comps = v:getComponents(req.cname)
    for i,c in ipairs(comps) do
      if c:isValid() and reg.component.id ~= c.id then
        msg.sender = c
        if reg.trackMe then
          print(""..reg.component.cname.." receieved component "..c.cname.." of type "..req.cname)
        end
        reg.callback(msg)
      end
    end
  end
  self:releaseLock(reqId)
  
end


function EntityManager:registerLocalRequest(req, reg)
  local reqId = self:getMessageRequestId(req.rtype, req.cname)

  if self.requestLocks[reqId].locked then
    table.insert(self.requestLocks[reqId].pendingLocalRequests, { req = req, reg = reg })
  end

  self.entities[reg.component.ownerId]:registerRequest(reqId, reg)

  if req.rtype ~= 'COMPONENT' then return end

  self:activateLock(reqId)

  local msg = Message:new('CREATE', nil)

  local comps = self.entities[reg.component.ownerId]:getComponents(req.cname)
  for i,v in ipairs(comps) do
    if v:isValid() and reg.component.id ~= v.id then
      msg.sender = v
      if reg.trackMe then
        print(""..reg.component.cname.." received component "..msg.sender.cname.." of type "..req.cname)
      end
      reg.callback(msg)
    end
  end

  self:releaseLock(reqId)
end

function EntityManager:getComponents(entityId, cname)
  return self.entities[entityId]:getComponents(cname)
end

function EntityManager:sendGlobalMessage(msg, component, payload)
  self:sendGlobalMessageObjectByRequestId(self:getExistingRequestId('MESSAGE', msg), Message:new('MESSAGE', component, payload))
end

function EntityManager:sendGlobalMessageByRequestId(requestId, component, payload)
  self:sendGlobalMessageObjectByRequestId(requestId, Message:new('MESSAGE', component, payload))
end

function EntityManager:sendGlobalMessageObjectByRequestId(requestId, msg)
  assert(msg.sender:isValid())

  self:activateLock(requestId)

  for i,v in ipairs(self.globalRequests[requestId]) do
    if v.trackMe then
      print(""..v.component.cname.." received message "..self.idToRequestMap['MESSAGE'][requestId].." from "..msg.sender.cname)
    end
    v.callback(msg)
  end
  self:releaseLock(requestId)
end

function EntityManager:sendMessageToEntity(msg, component, entityId, payload)
  self.entities[entityId]:sendMessageObjectByRequestId(self:getMessageRequestId('MESSAGE', msg), Message:new('MESSAGE', component, payload))
end

function EntityManager:sendMessageToEntityByRequestId(requestId, component, entityId, payload)
  self.entities[entityId]:sendMessageObjectByRequestId(requestId, Message:new('MESSAGE', component, payload), entityId)
end

function EntityManager:sendMessageObjectToEntity(cname, msg, entityId)
  self.entities[entityId]:sendMessageObjectByRequestId(self:getMessageRequestId('MESSAGE', cname), msg)
end

function EntityManager:sendMessageObjectToEntityByRequestId(requestId, msg, entityId)
  self.entities[entityId]:sendMessageObjectByRequestId(requestId, msg)
end

function EntityManager:getMessageRequestId(rtype, cname)
  if rtype == 'ALLCOMPONENTS' then rtype = 'COMPONENT' end

  if not self.requestToIdMap[rtype] then 
    self.requestToIdMap[rtype] = {}
    self.idToRequestMap[rtype] = {}
  end

  if not self.requestToIdMap[rtype][cname] then
    self.requestIdCounter = self.requestIdCounter + 1

    self.requestToIdMap[rtype][cname] = self.requestIdCounter
    self.idToRequestMap[rtype][self.requestIdCounter] = cname

    self.requestLocks[self.requestIdCounter] = RequestLock:new()

    return self.requestIdCounter
  else
    return self.requestToIdMap[rtype][cname]
  end
end

function EntityManager:trackRequest(requestId, isLocal, component)
end

function EntityManager:getRequestById(rtype, requestId)
  return self.idToRequestMap[rtype][requestId]
end

function EntityManager:getExistingRequestId(ctype, cname)
  if not self.requestToIdMap[ctype] or not self.requestToIdMap[ctype][cname] then
    return 1
  end
  local id = self.requestToIdMap[ctype][cname]

  return id
end

function EntityManager:activateLock(requestId)
  if self.requestLocks[requestId].locked then
    print("Do not request a message or component in a callback function for the same message/component request or a function called by this callback function")
    return
  end

  self.locks = self.locks + 1
  self.requestLocks[requestId].locked = true
end

function EntityManager:releaseLock(requestId)
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

    local deadEntities = self.deadEntities
    self.deadEntities = {}
    for k,v in ipairs(deadEntities) do
      self:destroyEntity(v)
    end
  end
end

return EntityManager
