require "class"

class "Object" {
   id = 0;
   localRequests = {};
   components = {};
   finalized = false;
}

function Object:__init(id)
   self.id = id
   self.finalized = false
   self.localRequests = {}
   self.components = {}
end

function Object:addComponent(component)
  if not component:isValid() then
    return false
  end

  if not self.components[component.name] then
    self.components[component.name] = {}
  end

  table.insert(self.components[component.name], component)
  return true
end

function Object:getComponents(name)
  if name then
    if not self.components[name] then
      return {}
    else
      return self.components[name]
    end
  else
    local comps = {}
    for n,v in pairs(self.components) do
      for i,c in ipairs(v) do
        table.insert(comps, c)
      end
    end
    return comps
  end
end

function Object:removeComponent(component)
   for n,v in pairs(self.components) do
      for i,c in ipairs(v) do
         if c == component then
            table.remove(v, i)
         end
      end
   end
   -- Now remove any local requests related to that component
   for i,reqs in ipairs(self.localRequests) do
      for i,r in ipairs(reqs) do
         if r.component == component then
            table.remove(self.localRequests, i)
         end
      end
   end
end

function Object:sendMessageObjectByRequestId(requestId, msgObject)
  if not self.localRequests[requestId] then return end

  local reqs = self.localRequests[requestId]
  if reqs then
    for i,r in ipairs(reqs) do
      if r.trackMe then
         local name = ""
         if msgObject.mtype == 'MESSAGE' then
            name = r.component.objectManager:getRequestById('MESSAGE', requestId)
         else
            name = r.component.objectManager:getRequestById('COMPONENT', requestId)
         end
         print(""..requestId.." - "..name)
      end
      r.callback(msgObject)
    end
  end
end

function Object:registerRequest(requestId, registeredComponent)
   if not self.localRequests[requestId] then
      self.localRequests[requestId] = {}
   end
   table.insert(self.localRequests[requestId], registeredComponent)
end

function Object:trackRequest(requestId, component)
   if #self.localRequests <= requestId then return end

   local reqs = self.localRequests[requestId]
   for i,r in ipairs(reqs) do
      if r.component == component then
         r.trackMe = true
      end
   end
end


