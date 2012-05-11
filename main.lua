local cf = require "comfuzion.comfuzion"

local Job = class("Job", cf.Component)
function Job:initialize()
  Job.super.initialize(self, "Job")
  self.salary = 0
end

function Job:addedToEntity()
   self:requestMessage("Fire", function(msg) self:fire(msg) end)
end

function Job:fire(msg)
  self:destroy()
end


local Person = class("Person", cf.Component)
function Person:initialize(name, age)
   Person.super.initialize(self, "Person")
   self.age = age
   self.pname = name
end

function Person:addedToEntity()
   print(self.pname.." with age "..self.age.." was added to the system")
   self:requestComponent("Job", function(msg) self:processJob(msg) end, true)
   self:requestMessage("NextYear", function(msg) self:nextYear(msg) end)
end

function Person:processJob(msg)
  local job = msg.sender
  if msg.mtype == 'CREATE' then
    print(self.pname.." (age "..self.age..") received a new job with salary "..job.salary)
  else
    print(self.pname.." (age "..self.age..") lost his job with salary "..job.salary)
  end
end

function Person:nextYear(msg)
   self.age = self.age + 1

   print(self.pname.." had a birthday and is now "..self.age.." years old")

   self:sendMessage("Birthday")
end


local Company = class("Company", cf.Component)
function Company:initialize()
  Company.super.initialize(self, "Company")
end

function Company:addedToEntity()
  self:requestComponent("Person", function(msg) self:processPerson(msg) end)
  self:requestMessage("Birthday", function(msg) self:processBirthday(msg) end)
end


function Company:processPerson(msg)
  local person = msg.sender

  if msg.mtype == 'CREATE' then
    local job = Job:new()
    local salary = person.age * 10000
    job.salary = salary
    self:addComponent(person.ownerId, job)

    if person.age >= 50 then
      local extraJob = Job:new()
      extraJob.salary = 50000
      self:addComponent(person.ownerId, extraJob)
    end
  end
end

function Company:processBirthday(msg)
  local person = msg.sender
  if person.age == 65 then
    self:sendMessageToEntity(person.ownerId, "Fire")
  end

  if person.age == 50 then
    local extraJob = Job:new()
    extraJob.salary = 50000
    self:addComponent(person.ownerId, extraJob)
  end
end


local Government = class("Government", cf.Component)
function Government:initialize()
  Government.super.initialize(self, "Government")
  self.totalEarnedIncome = 0
end

function Government:advanceCalendar()
  print("New fiscal year!")
  self:sendMessage("NextYear")
  print("Government annouces total earned salary at this year: "..self.totalEarnedIncome)
end

function Government:addedToEntity()
  self:requestComponent("Job", function(msg) self:processJob(msg) end)
end

function Government:processJob(msg)
  local job = msg.sender

  if msg.mtype == 'CREATE' then
    self.totalEarnedIncome = self.totalEarnedIncome + job.salary
  else
    self.totalEarnedIncome = self.totalEarnedIncome - job.salary
  end
end





om = cf.EntityManager:new()

p1Id = om:createEntity()
p1 = Person:new("Walter", 43)
om:addComponent(p1Id, p1)

companyId = om:createEntity()
company = Company:new()
om:addComponent(companyId, company)

p2Id = om:createEntity()
p2 = Person:new("Bob", 62)
om:addComponent(p2Id, p2)

p3Id = om:createEntity()
p3 = Person:new("Peter", 48)
om:addComponent(p3Id, p3)

governmentId = om:createEntity()
government = Government:new()
om:addComponent(governmentId, government)

government:advanceCalendar()
government:advanceCalendar()
government:advanceCalendar()
government:advanceCalendar()
