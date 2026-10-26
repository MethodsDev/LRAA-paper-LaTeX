-- One-time conversion of the Google Docs export (LRAA-2026-draft.docx) to LaTeX.
-- Run with: pandoc draft.docx --track-changes=all --natbib -L docx2tex.lua -t latex
-- env: KEYS (Paperpile ID -> bib key tsv), FIGDIR (where figure images are written),
--      IMGLOG (tsv log: media path, role, output name)
--
--  * Paperpile citation links (paperpile.com/c/<lib>/A+B) -> \citep{keyA,keyB}
--  * Paperpile reference list (paperpile.com/b/...) and the References header -> dropped (BibTeX)
--  * equation images linked to codecogs / mathjax-viewer -> the LaTeX in their URL
--  * figure image + "Figure N ..." / "Supplementary Figure N ..." paragraph -> figure with
--    caption and \label{fig:N} / \label{sfig:N}; "Figure 5d" in text -> Figure~\ref{fig:5}d
--  * tracked changes accepted; Google Docs comments -> \doccomment{author}{date}{text};
--    highlighted text -> \pending{...}

local keys = {}
for line in io.lines(os.getenv("KEYS")) do
  local id, key = line:match("^(%S+)\t(%S+)$")
  keys[id] = key
end
local figdir = os.getenv("FIGDIR")
local imglog = io.open(os.getenv("IMGLOG"), "w")

local function urldecode(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function latex_of(inlines)
  return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "latex", { wrap_text = "none" })
end

local function equation_of(link)
  local enc = link.target:match("codecogs%.com/eqnedit%.php%?latex=(.*)$")
    or link.target:match("mathjax%-viewer/%?input=(.*)$")
  if not enc then return nil end
  if #link.content ~= 1 or link.content[1].t ~= "Image" then return nil end
  imglog:write(link.content[1].src, "\tequation\t\n")
  local tex = urldecode(enc):gsub("#0$", "")
  return (tex:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- pass 1: inline rewrites --------------------------------------------------------------
local inline_pass = {
  Underline = function(el) return el.content end, -- Google Docs underlines its hyperlinks
  Link = function(el)
    local ids = el.target:match("paperpile%.com/c/%w+/([%w+]+)")
    if ids then
      local cites = {}
      for id in ids:gmatch("[^+]+") do
        assert(keys[id], "no bib key for Paperpile ID " .. id)
        table.insert(cites, pandoc.Citation(keys[id], "NormalCitation"))
      end
      return pandoc.Cite(el.content, cites)
    end
    local tex = equation_of(el)
    if tex then return pandoc.Math("InlineMath", tex) end
  end,
  Span = function(el)
    if el.classes:includes("insertion") then return el.content end
    if el.classes:includes("deletion") then return {} end
    if el.classes:includes("comment-end") then return {} end
    if el.classes:includes("comment-start") then
      local a = el.attributes
      return pandoc.RawInline("latex", "\\doccomment{" .. a.author .. "}{" .. a.date:sub(1, 10) ..
        "}{" .. latex_of(el.content) .. "}")
    end
    if el.classes:includes("underline") then return el.content end
    if el.classes:includes("mark") then
      if pandoc.utils.stringify(el.content):match("^%s*$") then return el.content end
      local out = { pandoc.RawInline("latex", "\\pending{") }
      for _, x in ipairs(el.content) do table.insert(out, x) end
      table.insert(out, pandoc.RawInline("latex", "}"))
      return out
    end
  end,
}

-- pass 2: blocks -----------------------------------------------------------------------
local function only_inline(blk)
  -- the inlines of a Para/Plain/Header/BlockQuote holding a single inline (ignoring spaces)
  local inl
  if blk.t == "Para" or blk.t == "Plain" or blk.t == "Header" then
    inl = blk.content
  elseif blk.t == "BlockQuote" and #blk.content == 1 then
    return only_inline(blk.content[1])
  else
    return nil
  end
  local found
  for _, x in ipairs(inl) do
    local note = x.t == "RawInline" and x.text:match("^\\doccomment")
    if x.t ~= "Space" and x.t ~= "SoftBreak" and x.t ~= "LineBreak" and not note then
      if found then return nil end
      found = x
    end
  end
  return found
end

local function is_blank(blk)
  return (blk.t == "Header" or blk.t == "Para" or blk.t == "Plain")
    and pandoc.utils.stringify(blk):match("^%s*$") ~= nil
end

-- remove the leading "Figure 1:" / "Supplementary Figure 3." words from caption inlines
local function strip_words(inlines, n)
  local out = pandoc.Inlines({})
  local i = 1
  while i <= #inlines do
    local x = inlines[i]
    if n > 0 and (x.t == "Strong" or x.t == "Emph") then
      local inner, left = strip_words(x.content, n)
      n = left
      if not pandoc.utils.stringify(inner):match("^%s*$") then
        x.content = inner
        out:insert(x)
      end
    elseif n > 0 and x.t == "Str" then
      n = n - 1
      if n == 0 then
        local rest = x.text:gsub("^%d+[%.:]?", "")
        if rest ~= "" and rest ~= x.text then out:insert(pandoc.Str(rest)) end
      end
    elseif n > 0 and x.t == "Space" then
      -- drop
    else
      out:insert(x)
    end
    i = i + 1
  end
  return out, n
end

local function trim_leading(inlines)
  while #inlines > 0 do
    local x = inlines[1]
    if x.t == "Space" then
      inlines:remove(1)
    elseif x.t == "Str" and x.text:match("^[%.:]$") then
      inlines:remove(1)
    elseif (x.t == "Strong" or x.t == "Emph") then
      trim_leading(x.content)
      if #x.content == 0 then inlines:remove(1) else return inlines end
    else
      return inlines
    end
  end
  return inlines
end

local function ext_of(src) return src:match("%.(%w+)$") end

-- Google Docs comments anchored on the image itself
local function notes_of(blk)
  local notes = pandoc.Inlines({})
  blk:walk({ RawInline = function(x) if x.text:match("^\\doccomment") then notes:insert(x) end end })
  return notes
end

local function make_figure(img, img_blk, cap_blk, kind, num)
  local name = (kind == "sfig" and "SuppFig" or "Fig") .. num .. "." .. ext_of(img.src)
  local _, contents = pandoc.mediabag.fetch(img.src)
  local fh = assert(io.open(figdir .. "/" .. name, "wb"))
  fh:write(contents)
  fh:close()
  imglog:write(img.src, "\t", kind, num, "\t", name, "\n")
  local nwords = kind == "sfig" and 3 or 2
  local cap = trim_leading((strip_words(cap_blk.content, nwords)))
  cap:extend(notes_of(img_blk))
  -- not a float: the legends are too long to share a page with the figure, so the legend
  -- follows the figure in the text (as in the Google Doc) and may run onto the next page
  return {
    pandoc.RawBlock("latex", "\\begin{center}\n\\pandocbounded{\\includegraphics{figures/docx_export/" ..
      name .. "}}\n\\end{center}"),
    pandoc.Para(pandoc.Inlines({ pandoc.RawInline("latex", "\\captionof{figure}{") }) ..
      cap .. pandoc.Inlines({ pandoc.RawInline("latex", "}\\label{" .. kind .. ":" .. num .. "}") })),
  }
end

local function block_pass(blocks)
  local out = pandoc.Blocks({})
  local i = 1
  local in_refs = false
  while i <= #blocks do
    local b = blocks[i]
    local text = pandoc.utils.stringify(b)
    if b.t == "Header" and b.level == 1 and text == "References" then
      in_refs = true
    elseif in_refs then
      -- drop the Paperpile reference list
    elseif b.t == "Para" and text:match("^%[moving to LaTeX") or text:match("^%[edits post%-biorxiv") then
      -- editorial notes from the Google Doc
    else
      local one = only_inline(b)
      local eq = one and one.t == "Math" and one.mathtype == "InlineMath"
      local img = one and one.t == "Image" and one
      if eq then
        out:insert(pandoc.Para(pandoc.Inlines({ pandoc.Math("DisplayMath", one.text) }) .. notes_of(b)))
      elseif img then
        local j = i + 1
        while j <= #blocks and is_blank(blocks[j]) do j = j + 1 end
        local cap = blocks[j]
        local ct = cap and pandoc.utils.stringify(cap) or ""
        local snum = ct:match("^Supplementary Figure (%d+)")
        local fnum = ct:match("^Figure (%d+)")
        if snum or fnum then
          out:extend(make_figure(img, b, cap, snum and "sfig" or "fig", snum or fnum))
          i = j
        else
          imglog:write(img.src, "\tUNCAPTIONED\t\n")
          out:insert(b)
        end
      elseif b.t == "Header" and text:match("^Table 1%.") then
        local j = i + 1
        while j <= #blocks and is_blank(blocks[j]) do j = j + 1 end
        if blocks[j] and blocks[j].t == "Table" then
          local tbl = blocks[j]
          tbl.caption = { long = { pandoc.Plain(trim_leading((strip_words(b.content, 2)))) } }
          tbl.attr = pandoc.Attr("tab:1")
          out:insert(tbl)
          i = j
        else
          out:insert(b)
        end
      elseif is_blank(b) then
        -- empty headers / paragraphs left by the Google Docs layout
      elseif b.t == "Header" and b.level > 1 and text:match("^Figure %d") then
        out:insert(b) -- caption without image: keep, flagged by the checks
      else
        out:insert(b)
      end
    end
    i = i + 1
  end
  return out
end

-- pass 3: "Figure 5d" -> Figure~\ref{fig:5}d (also "Fig. 1") --------------------------------------------
local function ref_inlines(inl)
  local out = pandoc.Inlines({})
  local i = 1
  while i <= #inl do
    local x, sp, nx = inl[i], inl[i + 1], inl[i + 2]
    local pre = x.t == "Str" and (x.text:match("^(.-Figures?)$") or x.text:match("^(.-Figs?%.)$"))
    local num, rest
    if pre and sp and sp.t == "Space" and nx and nx.t == "Str" then
      num, rest = nx.text:match("^(%d+)(.*)$")
    end
    if num then
      local prev = out[#out - 1]
      local supp = prev and prev.t == "Str" and prev.text:match("Supplementary$")
      out:insert(pandoc.Str(pre))
      out:insert(pandoc.RawInline("latex", "~\\ref{" .. (supp and "sfig" or "fig") .. ":" .. num .. "}"))
      if rest ~= "" then out:insert(pandoc.Str(rest)) end
      i = i + 3
    else
      out:insert(x)
      i = i + 1
    end
  end
  return out
end

function Pandoc(doc)
  doc = doc:walk(inline_pass)
  doc.blocks = block_pass(doc.blocks)
  doc = doc:walk({ Inlines = ref_inlines })
  imglog:close()
  return doc
end
