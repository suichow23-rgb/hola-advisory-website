const tabs = document.querySelectorAll(".tab");
const listingGrid = document.querySelector("#listing-grid");
const insightGrid = document.querySelector("#insight-grid");

const fallbackInsights = [
  { category: "Market Signal", title: "Vietnam consumer growth: where SMEs should test first", summary: "Short practical notes on sectors, customer behavior, and first-step tests for foreign SMEs.", sourceName: "HOLA Advisory", url: "#contact" },
  { category: "Operator Note", title: "Virtual office first, full office later", summary: "A lower-risk path for companies that want presence before committing to larger fixed costs.", sourceName: "HOLA Advisory", url: "#workspace" },
  { category: "Expansion Watch", title: "Acquisition, franchise, or start from zero?", summary: "A practical view on when buying, partnering, or franchising may be smarter than building everything from scratch.", sourceName: "HOLA Advisory", url: "#opportunities" }
];

const fallbackListings = [
  { type: "sale", category: "Business Sale", title: "Vietnam acquisition listing scan", summary: "A starting point for buyers reviewing public Vietnam business-sale leads before commissioning deeper screening.", location: "Vietnam", price: "Varies", sourceName: "BusinessesForSale", url: "https://www.businessesforsale.com/search/businesses-for-sale-in-vietnam" },
  { type: "franchise", category: "Franchise", title: "Vietnam franchise partner pipeline", summary: "Brands and operators seeking Vietnam partners, pilot locations, or master franchise routes.", location: "Vietnam", price: "Case by case", sourceName: "HOLA Advisory", url: "#contact" },
  { type: "property", category: "Property / Workspace", title: "Starter office and retail search", summary: "Workspace, virtual office, private office, and retail location routes for new Vietnam entrants.", location: "Ho Chi Minh City", price: "On request", sourceName: "HOLA Advisory", url: "#workspace" }
];

function escapeHtml(value) {
  return String(value || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function renderInsights(items) {
  insightGrid.innerHTML = items.slice(0, 6).map((item) => `
    <article>
      <span>${escapeHtml(item.category || "Insight")}</span>
      <h3>${escapeHtml(item.title)}</h3>
      <p>${escapeHtml(item.summary)}</p>
      <a href="${escapeHtml(item.url || "#")}" target="_blank" rel="noopener">${escapeHtml(item.sourceName || "Read source")}</a>
    </article>`).join("");
}

function renderListings(items) {
  listingGrid.innerHTML = items.slice(0, 9).map((item) => `
    <article class="listing-card" data-type="${escapeHtml(item.type || "sale")}">
      <span>${escapeHtml(item.category || "Opportunity")}</span>
      <h3>${escapeHtml(item.title)}</h3>
      <p>${escapeHtml(item.summary)}</p>
      <dl>
        <div><dt>Location</dt><dd>${escapeHtml(item.location || "Vietnam")}</dd></div>
        <div><dt>Price</dt><dd>${escapeHtml(item.price || "On request")}</dd></div>
      </dl>
      <a href="${escapeHtml(item.url || "#contact")}" target="_blank" rel="noopener">${escapeHtml(item.sourceName || "View source")}</a>
    </article>`).join("");
}

async function loadJson(path, fallback) {
  try {
    const response = await fetch(path, { cache: "no-store" });
    if (!response.ok) throw new Error("Feed unavailable");
    const data = await response.json();
    return Array.isArray(data.items) ? data.items : fallback;
  } catch {
    return fallback;
  }
}

function bindTabs() {
  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      const filter = tab.dataset.filter;
      tabs.forEach((item) => item.classList.remove("active"));
      tab.classList.add("active");
      document.querySelectorAll(".listing-card").forEach((listing) => {
        listing.hidden = !(filter === "all" || listing.dataset.type === filter);
      });
    });
  });
}

async function hydrateFeeds() {
  const [insights, opportunities] = await Promise.all([
    loadJson("data/insights.json", fallbackInsights),
    loadJson("data/opportunities.json", fallbackListings)
  ]);
  renderInsights(insights);
  renderListings(opportunities);
  bindTabs();
}

hydrateFeeds();
