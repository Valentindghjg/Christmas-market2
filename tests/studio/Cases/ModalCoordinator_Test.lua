--!strict
return function(t)
	local ModalCoordinator =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModalCoordinator"))
	local expect = t.expect

	t.test("claim closes the other holder", function()
		local modals = ModalCoordinator.new()
		local a, b = 0, 0
		modals.claim("LotManager", function()
			a += 1
		end)
		modals.claim("Team", function()
			b += 1
		end)
		expect.equal(a, 1)
		expect.equal(b, 0)
	end)

	t.test("claiming the same id calls nothing", function()
		local modals = ModalCoordinator.new()
		local a, b = 0, 0
		modals.claim("Team", function()
			a += 1
		end)
		modals.claim("Team", function()
			b += 1
		end)
		expect.equal(a, 0)
		expect.equal(b, 0)
		modals.closeAll()
		expect.equal(b, 1)
		expect.equal(a, 0)
	end)

	t.test("claim closes the base layer once", function()
		local modals = ModalCoordinator.new()
		local f = 0
		modals.setBase(function()
			f += 1
		end)
		modals.claim("LotManager", function() end)
		expect.equal(f, 1)
		modals.claim("Team", function() end)
		expect.equal(f, 1)
	end)

	t.test("finder opens over the base layer", function()
		local modals = ModalCoordinator.new()
		local f, g = 0, 0
		modals.setBase(function()
			f += 1
		end)
		modals.claim("Finder", function()
			g += 1
		end)
		expect.equal(f, 0)
		expect.equal(g, 0)
		modals.claim("Team", function() end)
		expect.equal(g, 1)
		expect.equal(f, 1)
	end)

	t.test("closeAll keeps the base layer", function()
		local modals = ModalCoordinator.new()
		local f, a = 0, 0
		modals.setBase(function()
			f += 1
		end)
		modals.claim("Finder", function()
			a += 1
		end)
		modals.closeAll()
		expect.equal(a, 1)
		expect.equal(f, 0)
		modals.claim("LotManager", function() end)
		expect.equal(f, 1)
	end)

	t.test("release forgets a holder", function()
		local modals = ModalCoordinator.new()
		local a = 0
		modals.claim("Team", function()
			a += 1
		end)
		modals.release("Team")
		modals.claim("LotManager", function() end)
		expect.equal(a, 0)
	end)

	t.test("setBase nil clears the base layer", function()
		local modals = ModalCoordinator.new()
		local f = 0
		modals.setBase(function()
			f += 1
		end)
		modals.setBase(nil)
		modals.claim("Team", function() end)
		expect.equal(f, 0)
	end)

	t.test("close callbacks may release and clear", function()
		local modals = ModalCoordinator.new()
		local f, b = 0, 0
		modals.setBase(function()
			f += 1
			modals.setBase(nil)
		end)
		modals.claim("Team", function()
			modals.release("Team")
		end)
		modals.claim("LotManager", function()
			b += 1
		end)
		expect.equal(f, 1)
		modals.closeAll()
		expect.equal(b, 1)
	end)

	t.test("OverBase holds only Finder", function()
		expect.equal(ModalCoordinator.OverBase.Finder, true)
		expect.equal(ModalCoordinator.OverBase.LotManager, nil)
		expect.equal(ModalCoordinator.OverBase.Team, nil)
	end)

	-- CM2-49: the tutorial hint bar reads the held modal and the base layer.
	t.test("reports the held modal and the base layer", function()
		local modals = ModalCoordinator.new()
		expect.equal(modals.held(), nil)
		expect.falsy(modals.hasBase())
		modals.setBase(function() end)
		expect.truthy(modals.hasBase())
		modals.claim("Shop", function() end)
		expect.equal(modals.held(), "Shop")
		expect.falsy(modals.hasBase())
		modals.release("Shop")
		expect.equal(modals.held(), nil)
	end)

	-- CM2-G11: the quest panel re-checks its auto-open after every modal change.
	t.test("notifies listeners after every change", function()
		local modals = ModalCoordinator.new()
		local calls = 0
		local hasBase: boolean? = nil
		local heldId: string? = nil
		modals.onChange(function()
			calls += 1
			hasBase = modals.hasBase()
			heldId = modals.held()
		end)
		modals.setBase(function() end)
		expect.equal(calls, 1)
		expect.equal(hasBase, true)
		modals.claim("Team", function() end)
		expect.equal(calls, 2)
		expect.equal(hasBase, false)
		expect.equal(heldId, "Team")
		modals.release("Team")
		expect.equal(calls, 3)
		expect.equal(heldId, nil)
		modals.closeAll()
		expect.equal(calls, 4)
	end)

	t.test("a removed listener is not called", function()
		local modals = ModalCoordinator.new()
		local calls = 0
		local remove = modals.onChange(function()
			calls += 1
		end)
		remove()
		modals.setBase(nil)
		expect.equal(calls, 0)
	end)
end
