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
    font-family: 'Newsreader', Georgia, serif; }
  canvas { display: block; }
  #hud { position: fixed; top: 12px; left: 14px; color: #7f849c;
    font-size: 13px; letter-spacing: .02em; pointer-events: none; }

  /* Note panel: pinned to the right third; the graph reflows into what's left. */
  #panel { position: fixed; top: 0; right: 0; width: 33.333vw; height: 100%;
    box-sizing: border-box; background: #181825; border-left: 1px solid #313244;
    color: #cdd6f4; display: none; flex-direction: column;
    box-shadow: -8px 0 24px rgba(0,0,0,0.35); }
  #panel.open { display: flex; }
  #panel header { display: flex; align-items: baseline; gap: 10px;
    padding: 18px 22px 12px; border-bottom: 1px solid #313244; }
  #panel h1 { margin: 0; flex: 1; font-size: 22px; font-weight: 600;
    color: #cba6f7; overflow-wrap: anywhere; }
  #panel .close { cursor: pointer; color: #7f849c; font-size: 22px;
    line-height: 1; user-select: none; }
  #panel .close:hover { color: #f38ba8; }
  #panel .body { flex: 1; overflow-y: auto; padding: 14px 22px 28px;
    font-size: 16px; line-height: 1.6; }
  #panel .body h1, #panel .body h2, #panel .body h3 { color: #89b4fa;
    margin: 1em 0 .4em; line-height: 1.25; }
  #panel .body h1 { font-size: 20px; }
  #panel .body h2 { font-size: 18px; }
  #panel .body h3 { font-size: 16px; }
  #panel .body p { margin: 0 0 .8em; }
  #panel .body ul { margin: 0 0 .8em; padding-left: 1.3em; }
  #panel .body code { background: #313244; padding: 1px 5px; border-radius: 4px;
    font-family: ui-monospace, monospace; font-size: 14px; }
  #panel .body pre { background: #11111b; padding: 12px 14px; border-radius: 6px;
    overflow-x: auto; }
  #panel .body pre code { background: none; padding: 0; }
  #panel .body a.wl { color: #f9e2af; text-decoration: none; cursor: pointer; }
  #panel .body a.wl:hover { text-decoration: underline; }
  #panel .body .ghost { color: #7f849c; font-style: italic; }
</style>
</head>
<body>
<div id="hud"></div>
<canvas id="c"></canvas>
<aside id="panel">
  <header><h1 id="panel-title"></h1><span class="close" id="panel-close">&times;</span></header>
  <div class="body" id="panel-body"></div>
</aside>
<script>
const DATA = /*__DATA__*/;

const canvas = document.getElementById('c');
const ctx = canvas.getContext('2d');
const panel = document.getElementById('panel');
const panelTitle = document.getElementById('panel-title');
const panelBody = document.getElementById('panel-body');
// Width the open panel steals from the right; 0 when closed. The graph's usable
// region is `canvas.width - panelW`, so opening the panel reflows it leftward.
let panelW = 0;
function resize() {
  canvas.width = innerWidth; canvas.height = innerHeight;
  if (panel.classList.contains('open')) panelW = canvas.width / 3;
}
addEventListener('resize', resize); resize();
const regionW = () => canvas.width - panelW;

// Build the working graph from the injected data.
const rawNodes = Array.isArray(DATA.nodes) ? DATA.nodes : [];
const rawEdges = Array.isArray(DATA.edges) ? DATA.edges : [];
const nodes = rawNodes.map(n => ({
  id: n.id, exists: n.exists, text: n.text, deg: 0,
  x: (Math.random() - 0.5) * 400, y: (Math.random() - 0.5) * 400, vx: 0, vy: 0,
}));
const index = {};
nodes.forEach(n => index[n.id] = n);
const links = rawEdges
  .map(e => ({ s: index[e.source], t: index[e.target] }))
  .filter(l => l.s && l.t && l.s !== l.t);
links.forEach(l => { l.s.deg++; l.t.deg++; });

document.getElementById('hud').textContent =
  nodes.length + ' notes · ' + links.length + ' links · click a note to open · f to fit';

// View transform (pan + zoom). Origin starts at screen centre.
let scale = 1, ox = canvas.width / 2, oy = canvas.height / 2;
// Interaction state, declared before the loop starts (tick/draw read these).
let dragging = null, hover = null, panning = false, px = 0, py = 0;
// Click-vs-drag tracking: a press that releases on the same orb without moving
// counts as a click and opens that note; anything with movement is a drag/pan.
let downNode = null, downX = 0, downY = 0, moved = false;
// While true, the view keeps every node framed. Any manual pan/zoom turns it
// off; `f` or a double-click turns it back on to recover a lost graph.
let autofit = true;
const toScreen = n => ({ x: ox + n.x * scale, y: oy + n.y * scale });
const radius = n => 4 + Math.sqrt(n.deg) * 2.5;

// Fit the whole graph into the viewport with a margin (capped zoom so a tiny
// graph isn't blown up absurdly).
function fitView() {
  if (!nodes.length) return;
  let minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
  for (const n of nodes) {
    if (n.x < minx) minx = n.x; if (n.x > maxx) maxx = n.x;
    if (n.y < miny) miny = n.y; if (n.y > maxy) maxy = n.y;
  }
  const pad = 90;
  const w = Math.max(maxx - minx, 1), h = Math.max(maxy - miny, 1);
  scale = Math.min((regionW() - pad) / w, (canvas.height - pad) / h, 1.6);
  ox = regionW() / 2 - (minx + maxx) / 2 * scale;
  oy = canvas.height / 2 - (miny + maxy) / 2 * scale;
}

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

function frame() {
  tick();
  if (autofit) fitView();
  draw();
  requestAnimationFrame(frame);
}

// Interaction: drag nodes, pan the background, wheel to zoom, hover to label.
function pick(mx, my) {
  for (let i = nodes.length - 1; i >= 0; i--) {
    const n = nodes[i], p = toScreen(n), r = radius(n) * scale + 4;
    if ((mx - p.x) ** 2 + (my - p.y) ** 2 <= r * r) return n;
  }
  return null;
}
canvas.addEventListener('mousedown', e => {
  const n = pick(e.clientX, e.clientY);
  downX = e.clientX; downY = e.clientY; moved = false;
  if (n) { dragging = n; downNode = n; }
  else { panning = true; autofit = false; px = e.clientX; py = e.clientY; }
});
canvas.addEventListener('dblclick', () => { autofit = true; });
addEventListener('keydown', e => {
  if (e.key === 'f' || e.key === 'F') autofit = true;
  else if (e.key === 'Escape') closePanel();
});
addEventListener('mousemove', e => {
  hover = dragging || pick(e.clientX, e.clientY);
  canvas.style.cursor = hover ? 'pointer' : (panning ? 'grabbing' : 'default');
  if ((dragging || panning) &&
      (Math.abs(e.clientX - downX) > 4 || Math.abs(e.clientY - downY) > 4)) moved = true;
  if (dragging) {
    dragging.x = (e.clientX - ox) / scale;
    dragging.y = (e.clientY - oy) / scale;
    dragging.vx = 0; dragging.vy = 0;
  } else if (panning) {
    ox += e.clientX - px; oy += e.clientY - py; px = e.clientX; py = e.clientY;
  }
});
addEventListener('mouseup', () => {
  // A press released on an orb it never left is a click: open that note.
  if (downNode && !moved) openNode(downNode);
  dragging = null; panning = false; downNode = null;
});

// --- Note panel -----------------------------------------------------------
// A deliberately small markdown renderer: headings, fenced code, bullet lists,
// inline code/bold/italic, and [[wikilinks]] (clickable — they open the linked
// note's panel). Not spec-complete, just enough to read a note comfortably.
const escapeHtml = s => s.replace(/[&<>"]/g,
  c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const inlineFmt = s => s
  .replace(/`([^`]+)`/g, '<code>$1</code>')
  .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
  .replace(/\*([^*]+)\*/g, '<em>$1</em>');
function inlineMd(s) {
  let out = '', last = 0, re = /\[\[([^\]]+)\]\]/g, m;
  while ((m = re.exec(s))) {
    out += inlineFmt(escapeHtml(s.slice(last, m.index)));
    const body = m[1];
    const id = body.replace(/[|#].*$/, '').trim();
    const alias = (body.includes('|') ? body.slice(body.indexOf('|') + 1) : body)
      .replace(/#.*$/, '').trim();
    out += '<a class="wl" data-id="' + escapeHtml(id) + '">' + escapeHtml(alias) + '</a>';
    last = re.lastIndex;
  }
  return out + inlineFmt(escapeHtml(s.slice(last)));
}
function renderMd(text) {
  const out = [];
  let inCode = false, list = null;
  const flush = () => { if (list !== null) { out.push('<ul>' + list + '</ul>'); list = null; } };
  for (const raw of text.split(/\r?\n/)) {
    if (/^```/.test(raw)) {
      flush();
      out.push(inCode ? '</code></pre>' : '<pre><code>');
      inCode = !inCode;
      continue;
    }
    if (inCode) { out.push(escapeHtml(raw) + '\n'); continue; }
    const h = raw.match(/^(#{1,3})\s+(.*)$/);
    if (h) { flush(); out.push('<h' + h[1].length + '>' + inlineMd(h[2]) + '</h' + h[1].length + '>'); continue; }
    const li = raw.match(/^\s*[-*+]\s+(.*)$/);
    if (li) { list = (list || '') + '<li>' + inlineMd(li[1]) + '</li>'; continue; }
    if (raw.trim() === '') { flush(); continue; }
    flush();
    out.push('<p>' + inlineMd(raw) + '</p>');
  }
  flush();
  if (inCode) out.push('</code></pre>');
  return out.join('');
}
function openNode(n) {
  panelTitle.textContent = n.id;
  panelBody.innerHTML = (n.exists && typeof n.text === 'string')
    ? renderMd(n.text)
    : '<p class="ghost">This note doesn\'t exist yet.</p>';
  panelBody.scrollTop = 0;
  panel.classList.add('open');
  panelW = canvas.width / 3;
  autofit = true; // reflow the graph into the space that's left
}
function closePanel() {
  if (!panel.classList.contains('open')) return;
  panel.classList.remove('open');
  panelW = 0;
  autofit = true;
}
document.getElementById('panel-close').addEventListener('click', closePanel);
panelBody.addEventListener('click', e => {
  const a = e.target.closest('a.wl');
  if (!a) return;
  const n = index[a.dataset.id];
  if (n) openNode(n);
});
canvas.addEventListener('wheel', e => {
  e.preventDefault();
  autofit = false;
  const f = e.deltaY < 0 ? 1.1 : 0.9;
  ox = e.clientX - (e.clientX - ox) * f;
  oy = e.clientY - (e.clientY - oy) * f;
  scale *= f;
}, { passive: false });

// Everything is wired up; start the render/simulation loop.
frame();
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
      -- Keep the raw note text so the browser can show it in the side panel
      -- when its orb is clicked (no round-trip back to Neovim needed).
      nodes[name].text = table.concat(lines, "\n")
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
  -- Notes are embedded verbatim in DATA, so a note containing `</script>` would
  -- otherwise close the inline <script> early. Escaping `<` as its JSON unicode
  -- form (which decodes back to `<` in the browser) makes that impossible.
  json = json:gsub("<", "\\u003c")
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
