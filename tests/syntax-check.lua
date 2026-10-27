local parsed=0
for _,path in ipairs(arg) do
    assert(loadfile(path))
    parsed=parsed+1
end
assert(parsed>0,"no Lua addon files were supplied")
print("PASS: Lua 5.0 syntax for " .. parsed .. " staged addon sources.")
