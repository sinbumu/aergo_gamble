------------------------------------------------------------------------------
-- Aergo Gamble Contract Da.
------------------------------------------------------------------------------

-- A internal type check function
-- @type internal
-- @param x variable to check
-- @param t (string) expected type
local function _typecheck(x, t)
    if (x and t == 'address') then
      assert(type(x) == 'string', "address must be string type")
      -- check address length
      assert(52 == #x, string.format("invalid address length: %s (%s)", x, #x))
      -- check character
      local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
      assert(nil == invalidChar, string.format("invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
    elseif (x and t == 'str128') then
      assert(type(x) == 'string', "str128 must be string type")
      -- check address length
      assert(128 >= #x, string.format("too long str128 length: %s", #x))
    else
      -- check default lua types
      assert(type(x) == t, string.format("invalid type: %s != %s", type(x), t or 'nil'))
    end
end

local function _emptyArrayCheck(x)
  assert(next(x), "emptyArrayCheck - table is empty")
end

state.var {
    --delegation white list
    _delegationAllowList = state.map(),
}

function constructor()
  setDelegationAllow(system.getSender(), true)
end

function _onlyProxyOwner()
    assert(system.getCreator() == system.getSender(), string.format("Gamble: only proxy owner. Owner: %s | sender: %s", system.getCreator(), system.getSender()))
end

--아르고 환불
function refund(addr, amount)
    _onlyProxyOwner()
    _typecheck(addr, 'address')
    contract.send(addr, amount)
end

function _delegationAllowCheck()
    assert(isDelegationAllow(system.getSender()), string.format("invalid fee_delegation sender: %s", system.getSender()))
end

function isDelegationAllow(address)
    _typecheck(address, 'address')
    if _delegationAllowList[address] ~= nil then
      return _delegationAllowList[address]
    end
    return false
end

function setDelegationAllow(address, state)
    --assert(system.getSender() == system.getCreator(), "Gamble: setDelegationAllow - only contract creator can setDelegationAllow")
    assert(system.getSender() == system.getCreator(), "Gamble: setDelegationAllow - only contract creator can setDelegationAllow")
    _typecheck(address, 'address')
    _typecheck(state, 'boolean')

    _delegationAllowList[address] = state
    contract.event("setDelegationAllow", address, state)
end

function setManyDelegationAllow(addressArr, state)
    _typecheck(state, 'boolean')
    assert(system.getSender() == system.getCreator(), "Gamble: setManyDelegationAllow - only contract creator can setManyDelegationAllow")
    for i, v in ipairs (addressArr) do
      _delegationAllowList[v] = state
    end
    contract.event("setManyDelegationAllow", state)
end

function check_delegation(fname, arg0)
    if (fname == "gamble") then
        return _delegationAllowList[system.getSender()]
    end
    return false
end

function gamble(tdArray, rParam)
  _delegationAllowCheck()
  return _gamble(tdArray, rParam)
end

--큰 수를 만든뒤, modNum으로 mod 하고 belowNum보다 낮으면 당첨, 높으면 낙첨.
--tdArray > [[groupId, allocation_rate], [groupId, allocation_rate] ...]
function _gamble(tdArray, rParam)
  _typecheck(rParam, 'str128')
  _emptyArrayCheck(tdArray)
  local modNum = 0;
  for i = 1, #tdArray, 1 do
    modNum = modNum + tdArray[i][2]
  end
  local gNumber = bignum.number(crypto.sha256(system.getPrevBlockHash()..system.getTimestamp()..system.getTxhash()..rParam))
  local modGNumber = bignum.mod(gNumber, modNum)
  local belowNum = 0;
  for i = 1, #tdArray, 1 do
    belowNum = belowNum + tdArray[i][2]
    if bignum.compare(modGNumber, bignum.number(belowNum)) == -1 then
      local groupId = tdArray[i][1]
      contract.event("gamble", tdArray, rParam, gNumber, modGNumber, belowNum, groupId)
      return groupId
    end
  end
  assert(true, "Gamble: not be decided groupId , something wrong")
end

function default()
end

abi.register(gamble, refund, setDelegationAllow, setManyDelegationAllow)
abi.register_view(isDelegationAllow, check_delegation)
abi.payable(default)
abi.fee_delegation(gamble)
