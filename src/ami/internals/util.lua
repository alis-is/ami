local function _append_to_url(p, ...)
    if type(p) == "string" then
        for _, _arg in ipairs(table.pack(...)) do
            if type(_arg) == "string" then
                p = path.combine(p, _arg)
            end
        end
    end
    return p
end

return {
    append_to_url = _append_to_url
}