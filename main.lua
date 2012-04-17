require "Component"
require "ObjectManager"

class "Job" : extends(Component) {
   salary = 0;
}

function Job:__init()
   self.super.__init(self, "Job")
   self.salary = 0
end

function Job:addedToObject()
   self:requestMessage("Fire", function(msg) self:fire(msg) end)
end

function Job:fire(msg)
  self:destroy()
end


class "Person" : extends(Component) {
   age = 0;
   pname = "";
}

function Person:__init(name, age)
   self.super.__init(self, "Person")
   self.age = age
   self.pname = name
end

function Person:addedToObject()
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


class "Company" : extends(Component) {
}

function Company:__init()
  self.super.__init(self, "Company")
end

function Company:addedToObject()
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
    self:sendMessageToObject(person.ownerId, "Fire")
  end

  if person.age == 50 then
    local extraJob = Job:new()
    extraJob.salary = 50000
    self:addComponent(person.ownerId, extraJob)
  end
end


class "Government" : extends(Component) {
  totalEarnedIncome = 0;
}

function Government:__init()
  self.super.__init(self, "Government")
end

function Government:advanceCalendar()
  print("New fiscal year!")
  self:sendMessage("NextYear")
  print("Government annouces total earned salary at this year: "..self.totalEarnedIncome)
end

function Government:addedToObject()
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





om = ObjectManager:new()

p1Id = om:createObject()
p1 = Person:new("Walter", 43)
om:addComponent(p1Id, p1)

companyId = om:createObject()
company = Company:new()
om:addComponent(companyId, company)

p2Id = om:createObject()
p2 = Person:new("Bob", 62)
om:addComponent(p2Id, p2)

p3Id = om:createObject()
p3 = Person:new("Peter", 48)
om:addComponent(p3Id, p3)

governmentId = om:createObject()
government = Government:new()
om:addComponent(governmentId, government)

government:advanceCalendar()
government:advanceCalendar()
government:advanceCalendar()
government:advanceCalendar()
