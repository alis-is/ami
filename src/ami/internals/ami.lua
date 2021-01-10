local function _load_ami()
    log_trace("Loading app specific ami...")
    local _ok, _subAmiContent = fs.safe_read_file("ami.json")
    if _ok then
        log_trace("ami.json found loading...")
        _ok, _subAmi = pcall(hjson.parse, _subAmiContent)
        log_trace("ami.json load " .. (_ok and "successful" or "failed") .. "...")
    end

    if not _ok then
        _ok, _subAmiContent = fs.safe_read_file("ami.hjson")
        if _ok then
            log_trace("ami.hjson found loading...")
            _ok, _subAmi = pcall(hjson.parse, _subAmiContent)
            log_trace("ami.hjson load " .. (_ok and "successful" or "failed") .. "...")
        end
    end

    if not _ok then
        _ok, _subAmiContent = fs.safe_read_file("ami.lua")
        if _ok then
            log_trace("ami.lua found loading...")
            _, _subAmi = pcall(load, _subAmiContent)
            _ok, _subAmi = pcall(_subAmi)
            if _ok then
                log_trace("ami.lua load successful...")
            else
                log_trace("ami.lua load failed - " .. _subAmi)
            end
        end
    end

    if type(_subAmi) ~= "table" then
        log_trace("App specific ami not found...")
        return false
    end

    local _id = am.__inteface.id
    local _title = exString.join_strings(" - ", am.__inteface.title, _subAmi.title)

    am.__inteface = util.merge_tables(am.__inteface, _subAmi, true)
    am.__inteface.id = _id
    am.__inteface.title = _title
    return true
end

return {
    load_sub_ami = _load_ami
}