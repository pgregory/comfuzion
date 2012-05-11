require "comfuzion.middleclass.middleclass"

local Message = class("Message")
function Message:initialize(mt, s, p)
  self.mtype = mt
  self.sender = s
  self.payload = p
end


return Message
