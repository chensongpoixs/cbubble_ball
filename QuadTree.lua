﻿local M = {}


local maxLevel = 5  --最大深度
local maxObjs  = 15


local Rect = {}
Rect.__index = Rect

--矩形
function M.rect(bottomLeftX,bottomLeftY,topRightX,topRightY)
	local o = {}
	o = setmetatable(o,Rect)
	o.topRight = {x = topRightX, y = topRightY}
	o.bottomLeft = {x = bottomLeftX, y = bottomLeftY}
	return o
end

--范围
local function in_range(topRight,bottomLeft,x,y)
	if x >= bottomLeft.x and y >= bottomLeft.y and x <= topRight.x and y <= topRight.y then
		return true
	else
		return false
	end
end

--相交
function Rect:intersect(other)
	local oTopLeft = {x = other.topRight.x - other:width(),y = other.topRight.y}
	local oBottomRight = {x = other.bottomLeft.x + other:width(),y = other.bottomLeft.y}

	if in_range(self.topRight,self.bottomLeft,oTopLeft.x,oTopLeft.y) then
		return true
	end

	if in_range(self.topRight,self.bottomLeft,oBottomRight.x,oBottomRight.y) then
		return true
	end

	if in_range(self.topRight,self.bottomLeft,other.topRight.x,other.topRight.y) then
		return true
	end

	if in_range(self.topRight,self.bottomLeft,other.bottomLeft.x,other.bottomLeft.y) then
		return true
	end

	return false

end

--返回与other是否完全被包含
function Rect:include(other)
	local oTopLeft = {x = other.topRight.x - other:width(),y = other.topRight.y}
	local oBottomRight = {x = other.bottomLeft.x + other:width(),y = other.bottomLeft.y}

	if not in_range(self.topRight,self.bottomLeft,oTopLeft.x,oTopLeft.y) then
		return false
	end

	if not in_range(self.topRight,self.bottomLeft,oBottomRight.x,oBottomRight.y) then
		return false
	end

	if not in_range(self.topRight,self.bottomLeft,other.topRight.x,other.topRight.y) then
		return false
	end

	if not in_range(self.topRight,self.bottomLeft,other.bottomLeft.x,other.bottomLeft.y) then
		return false
	end

	return true

end

--矩形高度
function Rect:height()
	return self.topRight.y - self.bottomLeft.y
end

--矩形宽度
function Rect:width()
	return self.topRight.x - self.bottomLeft.x
end

local QuadTree = {}
QuadTree.__index = QuadTree

local function new(index,rect,level)
	local o = {}
	o = setmetatable(o,QuadTree)
	o.rect = rect
	o.objs = {}
	o.obj_count = 0
	o.level = level
	o.index = index
	return o
end

function M.new(rect)
	return new(0,rect,1)
end


--[[

1 | 2
-----
3 | 4

]]


--获取rect所在象限
function QuadTree:getSubTree(rect)
	if self.nodes then
		for k,v in pairs(self.nodes) do
			if v.rect:include(rect) then
				return v
			end
		end
	end
	return nil
end

--四叉树：分离
function QuadTree:split()
   	local  subWidth = math.ceil(self.rect:width() / 2)
   	local  subHeight = math.ceil(self.rect:height() / 2)

   	local bottomLeft = self.rect.bottomLeft
   	local topRight = self.rect.topRight

   	self.nodes = {}

   	self.nodes[1] = new(1,M.rect(bottomLeft.x, bottomLeft.y + subHeight, bottomLeft.x + subWidth, topRight.y),self.level + 1)
   	self.nodes[2] = new(2,M.rect(bottomLeft.x + subWidth, bottomLeft.y + subHeight, topRight.x, topRight.y),self.level + 1)
   	self.nodes[3] = new(3,M.rect(bottomLeft.x, bottomLeft.y, bottomLeft.x + subWidth, bottomLeft.y + subHeight),self.level + 1)
   	self.nodes[4] = new(4,M.rect(bottomLeft.x + subWidth, bottomLeft.y, topRight.x, bottomLeft.y + subHeight),self.level + 1)
end

--四叉树：插入
function QuadTree:insert(obj)

	if obj.tree then
		error("obj.tree ~= nil")
	end

	if not self.rect:include(obj.rect) then
		--rect必须完全包含在self.rect中
		return false
	end


	local subTree = self:getSubTree(obj.rect)
	if subTree then
		return subTree:insert(obj)
	end

	--无法插入到子空间中，插入到当前树

	if self.obj_count + 1 > maxObjs and self.level < maxLevel and self.nodes == nil then
		self:split()
	end


	obj.tree = self
	self.objs[obj] = obj
	self.obj_count = self.obj_count + 1

	return true
end

--获取与rect相交的空间内的所有对象
function QuadTree:retrive(rect,objs)
	if not self.rect:intersect(rect) then
		return
	end

	if self.nodes then
		for k,v in pairs(self.nodes) do
			v:retrive(rect,objs)
		end
	end

	for k,v in pairs(self.objs) do
		table.insert(objs,v)
	end

end

--对每个与rect相交的空间内的对象执行func
function QuadTree:rectCall(rect,func)
	if not self.rect:intersect(rect) then
		return
	end

	if self.nodes then
		for k,v in pairs(self.nodes) do
			v:rectCall(rect,func)
		end
	end

	for k,v in pairs(self.objs) do
		func(v)
	end
end

--四叉树：移动
function QuadTree:remove(obj)
	if obj.tree == self then
		if self.objs[obj] then
			self.objs[obj] = nil
			obj.tree = nil
			self.obj_count = self.obj_count + 1
		end
	else
		error("obj.tree ~= self")
	end
end

--四叉树：更新
function QuadTree:update(obj)
	if self.level ~= 1 then
		error("update should call in level == 1")
	end

	local tree = obj.tree
	if tree then
		--[[
		需要执行更新的条件
		1 当前子树不能完全容纳obj.rect
		2 当前子树有任意一个子节点能完全容纳obj.rect
		]]

		while true do
			if not tree.rect:include(obj.rect) then
				break
			end

			local nodes = tree.nodes

			if nodes and (nodes[1].rect:include(obj.rect) or nodes[2].rect:include(obj.rect) or nodes[3].rect:include(obj.rect) or nodes[4].rect:include(obj.rect)) then
				break
			end

			return
		end

		obj.tree:remove(obj)
		self:insert(obj)

	end
end

return M
