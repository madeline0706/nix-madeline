-- visual.nvim
--
-- A tiny personal-wiki graph, built from the ground up. It scans a directory
-- of notes for [[wikilinks]], turns them into a graph (notes = nodes, links =
-- edges), and serves a single self-contained web page that draws an
-- Obsidian-style force-directed graph. No Node, no build step, no CDN: the web
-- server is libuv (bundled with Neovim) and the graph is vanilla canvas JS.
--
-- Public commands (see setup): :Visual, :VisualStop
-- In note buffers, `gf` on a [[link]] opens the target note.

local M = {}
local uv = vim.uv or vim.loop

M.config = {
  root = vim.fn.expand("~/notes"),
  extensions = { "md", "markdown", "txt" },
}

-- The one and only web page. `/*__DATA__*/` is replaced with the graph JSON at
-- serve time. Everything the browser needs is inlined here.
local PAGE = [==[
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>visual.nvim</title>
<style>
  html, body { margin: 0; height: 100%; overflow: hidden; background: #1e1e2e;
    font-family: ui-sans-serif, system-ui, sans-serif; }
  canvas { display: block; }
  #hud { position: fixed; top: 12px; left: 14px; color: #7f849c;
    font-size: 12px; letter-spacing: .02em; pointer-events: none; }
</style>
</head>
<body>
<div id="hud"></div>
<canvas id="c"></canvas>
<script>
const DATA = /*__DATA__*/;

const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
function resize() { canvas.width = innerWidth; canvas.height = innerHeight; }
addEventListener('resize', resize); resize();

// Build the working graph from the injected data.
const rawNodes = Array.isArray(DATA.nodes) ? DATA.nodes : [];
const rawEdges = Array.isArray(DATA.edges) ? DATA.edges : [];
const nodes = rawNodes.map(n => ({
  id: n.id, exists: n.exists, deg: 0,
  x: (Math.random() - 0.5) * 400, y: (Math.random() - 0.5) * 400, vx: 0, vy: 0,
}));
const index = {};
nodes.forEach(n => index[n.id] = n);
const links = rawEdges
  .map(e => ({ s: index[e.source], t: index[e.target] }))
  .filter(l => l.s && l.t && l.s !== l.t);
links.forEach(l => { l.s.deg++; l.t.deg++; });

document.getElementById('hud').textContent =
  nodes.length + ' notes · ' + links.length + ' links';

// View transform (pan + zoom). Origin starts at screen centre.
let scale = 1, ox = canvas.width / 2, oy = canvas.height / 2;
const toScreen = n => ({ x: ox + n.x * scale, y: oy + n.y * scale });
const radius = n => 4 + Math.sqrt(n.deg) * 2.5;

// One step of a small force simulation: node-node repulsion, edge springs,
// and a gentle pull toward the origin so disconnected notes don't drift away.
function tick() {
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i], b = nodes[j];
      let dx = a.x - b.x, dy = a.y - b.y;
      let d2 = dx * dx + dy * dy + 0.01;
      let d = Math.sqrt(d2), f = 2200 / d2;
      let fx = f * dx / d, fy = f * dy / d;
      a.vx += fx; a.vy += fy; b.vx -= fx; b.vy -= fy;
    }
  }
  for (const l of links) {
    let dx = l.t.x - l.s.x, dy = l.t.y - l.s.y;
    let d = Math.sqrt(dx * dx + dy * dy) + 0.01;
    let f = (d - 90) * 0.015;
    let fx = f * dx / d, fy = f * dy / d;
    l.s.vx += fx; l.s.vy += fy; l.t.vx -= fx; l.t.vy -= fy;
  }
  for (const n of nodes) {
    n.vx += -n.x * 0.0015; n.vy += -n.y * 0.0015;
    if (n === dragging) continue;
    n.vx *= 0.85; n.vy *= 0.85;
    n.x += n.vx; n.y += n.vy;
  }
}

function draw() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.lineWidth = 1;
  ctx.strokeStyle = 'rgba(147,153,178,0.22)';
  for (const l of links) {
    const a = toScreen(l.s), b = toScreen(l.t);
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
  }
  for (const n of nodes) {
    const p = toScreen(n), r = radius(n) * scale;
    ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    ctx.fillStyle = n === hover ? '#f9e2af' : (n.exists ? '#89b4fa' : '#585b70');
    ctx.fill();
    if (scale > 0.55 || n === hover) {
      ctx.fillStyle = n === hover ? '#f9e2af' : '#bac2de';
      ctx.font = '12px ui-sans-serif, system-ui, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(n.id, p.x, p.y - r - 5);
    }
  }
}

function frame() { tick(); draw(); requestAnimationFrame(frame); }
frame();

// Interaction: drag nodes, pan the background, wheel to zoom, hover to label.
let dragging = null, hover = null, panning = false, px = 0, py = 0;
function pick(mx, my) {
  for (let i = nodes.length - 1; i >= 0; i--) {
    const n = nodes[i], p = toScreen(n), r = radius(n) * scale + 4;
    if ((mx - p.x) ** 2 + (my - p.y) ** 2 <= r * r) return n;
  }
  return null;
}
canvas.addEventListener('mousedown', e => {
  const n = pick(e.clientX, e.clientY);
  if (n) { dragging = n; } else { panning = true; px = e.clientX; py = e.clientY; }
});
addEventListener('mousemove', e => {
  hover = dragging || pick(e.clientX, e.clientY);
  canvas.style.cursor = hover ? 'pointer' : (panning ? 'grabbing' : 'default');
  if (dragging) {
    dragging.x = (e.clientX - ox) / scale;
    dragging.y = (e.clientY - oy) / scale;
    dragging.vx = 0; dragging.vy = 0;
  } else if (panning) {
    ox += e.clientX - px; oy += e.clientY - py; px = e.clientX; py = e.clientY;
  }
});
addEventListener('mouseup', () => { dragging = null; panning = false; });
canvas.addEventListener('wheel', e => {
  e.preventDefault();
  const f = e.deltaY < 0 ? 1.1 : 0.9;
  ox = e.clientX - (e.clientX - ox) * f;
  oy = e.clientY - (e.clientY - oy) * f;
  scale *= f;
}, { passive: false });
</script>
</body>
</html>
]==]

-- Collect every note file under `root` for the configured extensions.
local function list_notes(root, exts)
  local files, seen = {}, {}
  for _, ext in ipairs(exts) do
    for _, f in ipairs(vim.fn.glob(root .. "/**/*." .. ext, false, true)) do
      if not seen[f] then
        seen[f] = true
        files[#files + 1] = f
      end
    end
  end
  return files
end

-- Normalise a raw [[link]] body to a note name: drop |aliases and #headings.
local function link_name(raw)
  return vim.trim((raw:gsub("|.*$", ""):gsub("#.*$", "")))
end

-- Scan the notes and build { nodes = {...}, edges = {...} }. A node exists when
-- there is a real file behind it; a link to a missing note is a ghost node.
local function build_graph(root, exts)
  local nodes, order, edges = {}, {}, {}
  local function ensure(name, exists)
    if not nodes[name] then
      nodes[name] = { id = name, exists = exists }
      order[#order + 1] = name
    elseif exists then
      nodes[name].exists = true
    end
  end

  for _, file in ipairs(list_notes(root, exts)) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    ensure(name, true)
    local ok, lines = pcall(vim.fn.readfile, file)
    if ok then
      for _, line in ipairs(lines) do
        for raw in line:gmatch("%[%[(.-)%]%]") do
          local target = link_name(raw)
          if target ~= "" then
            ensure(target, false)
            edges[#edges + 1] = { source = name, target = target }
          end
        end
      end
    end
  end

  local nodelist = {}
  for _, name in ipairs(order) do
    nodelist[#nodelist + 1] = nodes[name]
  end
  return { nodes = nodelist, edges = edges }
end

local function render_page(graph)
  local json = vim.json.encode(graph)
  return (PAGE:gsub("/%*__DATA__%*/", function() return json end))
end

local server -- kept alive between :Visual calls so the page stays reachable

function M.stop()
  if server and not server:is_closing() then
    server:close()
  end
  server = nil
end

local function open_url(url)
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
  else
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  end
end

-- Build the graph, (re)start the server on a random free port, open a browser.
function M.open()
  local root = M.config.root
  if vim.fn.isdirectory(root) == 0 then
    vim.notify("visual.nvim: notes directory not found: " .. root, vim.log.levels.ERROR)
    return
  end

  local page = render_page(build_graph(root, M.config.extensions))
  local response = "HTTP/1.1 200 OK\r\n"
    .. "Content-Type: text/html; charset=utf-8\r\n"
    .. "Content-Length: " .. #page .. "\r\n"
    .. "Connection: close\r\n\r\n"
    .. page

  M.stop()
  server = uv.new_tcp()
  local ok, err = pcall(function()
    server:bind("127.0.0.1", 0) -- port 0 => OS picks a free one
    server:listen(64, function(lerr)
      if lerr then return end
      local client = uv.new_tcp()
      server:accept(client)
      -- We ignore the request contents; every request gets the same page.
      client:read_start(function(rerr, chunk)
        if rerr or not chunk then
          client:read_stop()
          if not client:is_closing() then client:close() end
          return
        end
        client:write(response, function()
          client:shutdown(function()
            if not client:is_closing() then client:close() end
          end)
        end)
      end)
    end)
  end)
  if not ok then
    vim.notify("visual.nvim: could not start server: " .. tostring(err), vim.log.levels.ERROR)
    M.stop()
    return
  end

  local port = server:getsockname().port
  local url = ("http://127.0.0.1:%d/"):format(port)
  vim.notify("visual.nvim: serving graph at " .. url)
  open_url(url)
end

-- `gf` in a note buffer: if the cursor sits inside a [[link]], open that note
-- (creating the path if it doesn't exist yet); otherwise fall back to builtin gf.
function M.follow()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".")
  local from = 1
  while true do
    local s, e, raw = line:find("%[%[(.-)%]%]", from)
    if not s then break end
    if col >= s and col <= e then
      local name = link_name(raw)
      if name ~= "" then
        local ext = M.config.extensions[1] or "md"
        local target = ("%s/%s.%s"):format(M.config.root, name, ext)
        vim.cmd.edit(vim.fn.fnameescape(target))
        return
      end
    end
    from = e + 1
  end
  vim.cmd("normal! gf")
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("Visual", function() M.open() end,
    { desc = "Open the visual.nvim note graph in the browser" })
  vim.api.nvim_create_user_command("VisualStop", function() M.stop() end,
    { desc = "Stop the visual.nvim web server" })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text", "pandoc" },
    callback = function(ev)
      vim.keymap.set("n", "gf", M.follow,
        { buffer = ev.buf, desc = "Follow [[wikilink]]" })
    end,
  })
end

return M
