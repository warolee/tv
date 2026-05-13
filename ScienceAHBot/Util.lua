local Util = {}

function Util.safe_call(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    local trace = ""
    pcall(function()
      trace = debug.traceback(tostring(err), 2) or ""
    end)
    local msg = #trace > 0 and trace or tostring(err)
    pcall(function()
      if core and core.log_warning then
        core.log_warning(string.format("[ScienceAHBot][%s] %s", tostring(label), msg))
      end
    end)
  end
  return ok
end

return Util
