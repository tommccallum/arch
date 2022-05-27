#!/usr/bin/env lua5.3

-- token types
local UNKNOWN=0
local TEXT=1
local NUMBER=2
local VARIABLE=3
local OPERATOR=4
local OPENBRACKET =5
local CLOSEBRACKET=6

-- return types
local ERROR   = -1
local SUCCESS =  0

-- precedence and association for using the shunting yard algorithm
local precedence = {
    ["+"] = 11,
    ["-"] = 11,
    ["*"] = 12,
    ["/"] = 12,
    ["^"] = 13,
    ["UNARY_PLUS"] = 14,
    ["UNARY_MINUS"] = 14,
    ["("] = 15,
    [")"] = 15
}

local LEFT_ASSOCIATIVE=0
local RIGHT_ASSOCIATIVE=1

local association = {
    ["+"]           = LEFT_ASSOCIATIVE,
    ["-"]           = LEFT_ASSOCIATIVE,
    ["*"]           = LEFT_ASSOCIATIVE,
    ["/"]           = LEFT_ASSOCIATIVE,
    ["("]           = LEFT_ASSOCIATIVE,
    [")"]           = LEFT_ASSOCIATIVE,
    ["^"]           = RIGHT_ASSOCIATIVE,
    ["UNARY_PLUS"]  = RIGHT_ASSOCIATIVE,
    ["UNARY_MINUS"] = RIGHT_ASSOCIATIVE,
}

-- Stack Table
-- Uses a table as stack, use <table>:push(value) and <table>:pop()
-- Lua 5.1 compatible

-- GLOBAL
Stack = {}

-- Create a Table with stack functions
function Stack:Create()

  -- stack table
  local t = {}
  -- entry table
  t._et = {}

  -- push a value on to the stack
  function t:push(...)
    if ... then
      local targs = {...}
      -- add values
      for _,v in ipairs(targs) do
        table.insert(self._et, v)
      end
    end
  end

  -- pop a value from the stack
  function t:pop(num)

    -- get num values from stack
    local num = num or 1

    -- return table
    local entries = {}

    -- get values into entries
    for i = 1, num do
      -- get last entry
      if #self._et ~= 0 then
        table.insert(entries, self._et[#self._et])
        -- remove last value
        table.remove(self._et)
      else
        break
      end
    end
    -- return unpacked entries
    return table.unpack(entries)
  end

  -- get entries
  function t:getn()
    return #self._et
  end

  -- list values
  function t:list()
    for i,v in pairs(self._et) do
        if type(v) == "table" then
          print(i .. ": " .. dump(v))
        else
          print(i, v)
        end
    end
  end
  return t
end


function makeNewNumber(val) 
    local token = {
        type=NUMBER,
        num=val,
        key=val
    }
    return token
end

function makeNewOpenBracket(val) 
    local token = {
        type=OPENBRACKET,
        text=val,
        key="("
    }
    return token
end

function makeNewCloseBracket(val) 
    local token = {
        type=CLOSEBRACKET,
        text=val,
        key=")"
    }
    return token
end


function isOperator(x)
    if ( x == "+" or x == "-" or x == "/" or x == "*" or x == "^" ) then
        return true
    end
    return false
end

function makeNewOperator(val)
    local token = {
        type = OPERATOR,
        text=val,
        key=val
    }
    return token
end

function isDigit(x)
    return tonumber(x) ~= nil
end

function getc(text, ii)
    local n = string.len(text)
    if ii > n then
        return nil
    end
    return string.sub(text,ii,ii)
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function getConstant(x)
    if x == "pi" then
        return 3.14159265359
    elseif x == "e" then
        return 2.718281828459
    else
        return nil
    end
end


function parse(text)
    local tokens = {}
    local chii = 1
    local buffer = nil
    while chii <= string.len(text)
    do
         ch = getc(text,chii)
         if ch == nil then
             break
         end
         if ch == ' ' then
             goto nextchar
         end
         if isOperator(ch) then
             op = makeNewOperator(ch)
             table.insert(tokens, op)
             goto nextchar
         end
         if ch == "(" then
             op = makeNewOpenBracket(ch)
             table.insert(tokens,op)
             goto nextchar
         end
         if ch == ")" then
             op = makeNewCloseBracket(ch)
             table.insert(tokens,op)
             goto nextchar
         end
         if isDigit(ch) then
            local startNumberText = chii
            chii = chii + 1
            local isFloat = false
            while chii <= string.len(text)
            do
                ch = getc(text,chii)
                if isDigit(ch) then
                elseif ch == '.' and isFloat == false then
                    isFloat = true
                else
                    break
                end
                chii = chii + 1
            end
            local t = string.sub(text, startNumberText, chii-1)
            local num = makeNewNumber(tonumber(t))            
            table.insert(tokens, num)
            chii = chii - 1
            goto nextchar
         end

         -- anything else is some sort of variable or constant
         buffer = ch
         chii = chii + 1
         ch = getc(text, chii)
         while ch ~= nil and ch ~= ' ' do
            buffer = buffer .. ch
            chii = chii + 1
            ch = getc(text, chii)
         end
         x = getConstant(buffer)
         if x == nil then
             return {
                 type= ERROR,
                 text= "variables are not currently supported"
             }
         else
             table.insert(tokens, makeNewNumber(x))
         end
         goto skipchar
::nextchar::
         chii = chii + 1
::skipchar::
    end
    return tokens
end

function evaluate_binary_operator(op, a, b)
    if op.key == "+" then
        return a.num + b.num
    elseif op.key == "-" then
        return a.num - b.num
    elseif op.key == "*" then
        return a.num * b.num
    elseif op.key == "/" then
        if b.num == 0 then
            return {
                type=ERROR,
                text="cannot divide by zero"
            }
        end
        return a.num / b.num
    elseif op.key == "^" then
        return a.num ^ b.num
    end
    return {
        type=ERROR,
        text = "invalid operator " .. op.text .. " (key: " .. op.key .. ") found in expression"
    }
end

function evaluate_unary_operator(op, a)
    if op.key == "UNARY_PLUS" then
        a.num = 1 * a.num
        return a
    elseif op.key == "UNARY_MINUS" then
        a.num = -1 * a.num
        return a.num
    end
    return a.num
end

function infix2postfix(tokens)
    local operators = {}
    local output = {}
    local lastToken = nil
    for k,v in ipairs(tokens) do

        if v.type == NUMBER then
            table.insert(output, v)
        elseif v.type == FUNCTION then
            table.insert(operators, v)
        elseif v.type == OPERATOR then
            if lastToken == nil or (lastToken.type ~= NUMBER and lastToken.type ~= FUNCTION and lastToken.type ~= CLOSEBRACKET) then
                if v.key == "-" then
                    v.key = "UNARY_MINUS"
                elseif v.key == "+" then
                    v.key = "UNARY_PLUS"
                else
                    return {
                        type=ERROR,
                        text="unexpected operator " .. v.text .. ", which is not + or -"
                    }
                end
                table.insert(operators, v)
            else
                if #operators > 0 then
                    local topOp = operators[#operators]
                    while topOp.type ~= OPENBRACKET and 
                        (precedence[topOp.key] > precedence[v.key] or 
                        (precedence[topOp.key] == precedence[v.text] and association[v.key] == LEFT_ASSOCIATIVE))
                    do
                        table.insert(output, topOp)
                        operators[#operators] = nil
                        if #operators == 0 then
                            break
                        end
                        topOp = operators[#operators]
                    end
                end 
                table.insert(operators, v)
            end
        elseif v.type == OPENBRACKET then
            table.insert(operators, v)
        elseif v.type == CLOSEBRACKET then
            local top = #operators
            if top == 0 then
                return {
                    type = ERROR,
                    text = "unexpected close bracket without paired open bracket"
                }
            else
                local t = operators[top]
                while t.type ~= OPENBRACKET 
                do
                    if #operators == 0 then
                        break
                    end
                    table.insert(output, operators[top])
                    operators[top] = nil
                    t = operators[#operators]
                end
                top = #operators
                if operators[top].type ~= OPENBRACKET then
                    return {
                        type=ERROR,
                        text="expected open bracket, found " .. operators[top].text
                    }
                end
            end
            operators[top] = nil
            top = #operators
            if operators[top].type == FUNCTION then
                table.insert(output, operators[top])
                output[top] = nil
            end
        end
        lastToken = v
    end

    while #operators > 0 do
        if operators[#operators].type == OPENBRACKET then
            return { 
                type=ERROR,
                text="unpaired bracket in expression"
            }
        end
        table.insert( output, operators[#operators] )
        operators[#operators] = nil
    end

    return output 
end

function evaluate(stack)
    local pending = Stack:Create()
    for k,v in ipairs(stack) do
        if v.type == OPERATOR then
            if v.key == "UNARY_PLUS" or v.key == "UNARY_MINUS" then
                if pending:getn() < 1 then
                    return {
                        type=ERROR,
                        text="expected at least one operand on stack during evaluation"
                    }
                end
                local top = pending:pop()
                local result = evaluate_unary_operator(v, top)
                if type(result) == "table" then
                    return result
                end
                pending:push(makeNewNumber(result))
            else
                if pending:getn() < 2 then
                    return {
                        type=ERROR,
                        text="expected at least one operand on stack during evaluation"
                    }
                end
                local b = pending:pop()
                local a = pending:pop()
                local result = evaluate_binary_operator(v, a, b)
                if type(result) == "table" then
                    return result
                end
                pending:push(makeNewNumber(result))
            end
        elseif v.type == NUMBER then
            pending:push(v)
        end
    end
    return pending:pop()
end

function isError(x) 
    if type(x) == "table" and x["type"] ~= nil then
        if x.type == ERROR then
            return true
        end
    end
    return false
end

function calc(x) 
    local s = parse(x)
    if isError(s) then
        return s
    end
    local e = infix2postfix(s)
    if isError(e) then
        return e
    end
    local r = evaluate(e)
    if isError(r) then
        return r
    end
    return r.num
end

function round(x, p) 
    return math.floor(x * 10^p) / 10^p
end


assert(round(1.23456,3)==1.234)
assert(calc("3 + 4 * 2 / ( 1 - 5 ) ^ 2 ^ 3") == 3.0001220703125)
assert(round(calc("pi + e"),3) == 5.859)
assert(calc("2")== 2)
assert(calc("-2+3")== 1)
assert(isError(calc(")")))
assert(isError(calc("(")))
assert(calc("pi")== getConstant("pi"))
assert(calc("e")==getConstant("e"))

assert(isError(calc("x")))
