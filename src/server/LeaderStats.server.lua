local Players = game:GetService("Players")
Players.PlayerAdded:Connect(function(p)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = p
	local sc = Instance.new("IntValue")
	sc.Name = "Score"
	sc.Parent = ls
end)
