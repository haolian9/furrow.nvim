local augroups = require("infra.augroups")
local buflines = require("infra.buflines")
local Ephemeral = require("infra.Ephemeral")
local jelly = require("infra.jellyfish")("furrow.interactive", "debug")
local bufmap = require("infra.keymap.buffer")
local ni = require("infra.ni")
local rifts = require("infra.rifts")
local vsel = require("infra.vsel")

local furrow = require("furrow")
local profiles = require("furrow.profiles").Vim

local param_xm_ns = ni.create_namespace("furrow:interactive:params")
local preview_xm_ns = ni.create_namespace("furrow:interactive:preview")

---@param xmid integer
---@return string?
local function get_anchor_line(bufnr, xmid)
  local xm = ni.buf_get_extmark_by_id(bufnr, param_xm_ns, xmid, { details = true })
  if #xm == 0 then return end
  ---@diagnostic disable-next-line: undefined-field
  if xm[3].invalid then return end
  local lnum = xm[1]
  local line = buflines.line(bufnr, lnum)
  if line == "" then return end
  return line
end

return function()
  local host_winid = ni.get_current_win()
  local host_bufnr = ni.win_get_buf(host_winid)
  local range = assert(vsel.range(host_bufnr))

  local param_bufnr = Ephemeral({ modifiable = true, undolevels = 5 }, { "spc", "left", "3" })

  local xmids = {}
  xmids.mode = ni.buf_set_extmark(param_bufnr, param_xm_ns, 0, 0, { virt_text = { { "mode", "question" }, { "  " } }, virt_text_pos = "eol", invalidate = true, undo_restore = true })
  xmids.gravity = ni.buf_set_extmark(param_bufnr, param_xm_ns, 1, 0, { virt_text = { { "gravity", "question" }, { "  " } }, virt_text_pos = "eol", invalidate = true, undo_restore = true })
  xmids.max_cols = ni.buf_set_extmark(param_bufnr, param_xm_ns, 2, 0, { virt_text = { { "max_cols", "question" }, { " " } }, virt_text_pos = "eol", invalidate = true, undo_restore = true })

  --stylua: ignore start
  local param_winid = rifts.open.win(param_bufnr, true, {
    relative = "cursor",
    border = "single",
    col = 0, row = range.stop_line - range.start_line + 1,
    width = 25, height = 3,
  })
  --stylua: ignore end
  ni.win_set_hl_ns(param_winid, rifts.ns)

  local aug = augroups.BufAugroup(param_bufnr, false)

  local lines = buflines.lines(host_bufnr, range.start_line, range.stop_line)
  local furrows

  do
    local bm = bufmap.wraps(param_bufnr)
    local confirmed = true
    local function noconfirm()
      confirmed = false
      ni.win_close(param_winid, false)
    end
    local function confirm()
      confirmed = true
      ni.win_close(param_winid, false)
    end
    bm.n("<c-c>", noconfirm)
    bm.n("<esc>", noconfirm)
    bm.n("q", noconfirm)
    bm.n("<cr>", confirm)

    aug:once("BufWipeout", {
      callback = function()
        aug:unlink()
        assert(furrows ~= nil)
        if confirmed then buflines.replaces(host_bufnr, range.start_line, range.stop_line, furrows) end
        ---NB: xmarks can conflict with buflines.*
        ni.buf_clear_namespace(host_bufnr, preview_xm_ns, 0, -1)
      end,
    })
  end

  aug:repeats({ "InsertLeave", "TextChanged" }, {
    callback = function()
      local mode = get_anchor_line(param_bufnr, xmids.mode)
      local gravity = get_anchor_line(param_bufnr, xmids.gravity)
      local max_cols = get_anchor_line(param_bufnr, xmids.max_cols)
      if not (mode and gravity and max_cols) then return jelly.info("incomplete params") end
      ---@diagnostic disable-next-line: cast-local-type
      max_cols = assert(tonumber(max_cols))

      local profile = profiles[mode]
      if profile == nil then return jelly.warn("unexpected mode: %s", mode) end

      local analysis = furrow.analyse(lines, profile.pattern, max_cols)
      furrows = furrow.furrows(analysis, gravity, profile.clods, profile.trailing)

      ni.buf_clear_namespace(host_bufnr, preview_xm_ns, range.start_line, range.stop_line)

      for i, line in ipairs(furrows) do
        local lnum = i + range.start_line - 1
        ni.buf_set_extmark(host_bufnr, preview_xm_ns, lnum, 0, {
          virt_text = { { line } },
          virt_text_pos = "overlay",
          invalidate = true,
          undo_restore = false,
        })
      end
    end,
  })
end
