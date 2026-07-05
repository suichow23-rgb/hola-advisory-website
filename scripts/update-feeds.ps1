param(
  [string]$Root = (Resolve-Path "$PSScriptRoot\..").Path,
  [int]$InsightLimit = 6,
  [int]$OpportunityLimit = 8
)

$ErrorActionPreference = "Stop"

$websiteDataDir = Join-Path $Root "website\data"
$rootDataDir = Join-Path $Root "data"
$dataDir = if (Test-Path -LiteralPath $websiteDataDir) { $websiteDataDir } else { $rootDataDir }
$configPath = Join-Path $dataDir "source-config.json"
$insightsPath = Join-Path $dataDir "insights.json"
$opportunitiesPath = Join-Path $dataDir "opportunities.json"

$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json

$vietnamTerms = @(
  "vietnam", "viet nam", "hcm", "ho chi minh", "ha noi", "hanoi", "da nang",
  "dong", "vn-index", "fdi", "mekong", "binh duong", "dong nai"
)

$businessTerms = @(
  "economy", "economic", "business", "investment", "investor", "infrastructure",
  "retail", "consumer", "property", "real estate", "industrial", "logistics",
  "manufacturing", "export", "import", "finance", "bank", "market", "stock",
  "gold", "tax", "policy", "carbon", "energy", "ai", "data center", "airport",
  "metro", "franchise", "company", "sales", "services", "trade"
)

$excludedRegionalTerms = @(
  "singapore comeback", "indonesia", "malaysia", "thailand", "philippines",
  "south korea", "korea", "china", "japan", "us stocks"
)

$excludedOpportunityTerms = @(
  "advertise", "franchise opportunities", "buy a franchise resale",
  "businesses for sale in spain", "sell a business", "business wanted",
  "business brokers", "login", "sign up", "businesses for sale in vietnam",
  "real property businesses for sale", "lease businesses for sale",
  "relocatable businesses for sale", "buy a franchise", "franchise articles",
  "add franchise", "create franchise profile", "distributor profile",
  "franchise your business"
)

$excludedOpportunityProfileTerms = @(
  "individual buyer", "corporate acquirer", "financial investor",
  "strategic investor", "business loan", "investment bank",
  "looking to buyout", "looking to acquire", "advisor in",
  "consultant in", "broker in", "director in"
)

function Write-JsonFile {
  param([string]$Path, [object]$Payload)
  $json = $Payload | ConvertTo-Json -Depth 8
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function ConvertTo-PlainText {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
  $plain = $Text -replace "<script[\s\S]*?</script>", " "
  $plain = $plain -replace "<style[\s\S]*?</style>", " "
  $plain = $plain -replace "<[^>]+>", " "
  $plain = [System.Net.WebUtility]::HtmlDecode($plain)
  return ($plain -replace "\s+", " ").Trim()
}

function ConvertTo-AbsoluteUrl {
  param([string]$BaseUrl, [string]$Href)
  if ([string]::IsNullOrWhiteSpace($Href)) { return "" }
  if ($Href.StartsWith("#") -or $Href.StartsWith("javascript:") -or $Href.StartsWith("mailto:")) { return "" }
  try {
    $base = [Uri]$BaseUrl
    return ([Uri]::new($base, $Href)).AbsoluteUri
  } catch {
    return $Href
  }
}

function Test-ContainsAny {
  param([string]$Text, [string[]]$Terms)
  $lower = $Text.ToLowerInvariant()
  foreach ($term in $Terms) {
    if ($lower.Contains($term)) { return $true }
  }
  return $false
}

function Test-VietnamBusinessHeadline {
  param([string]$Text, [string]$SourceName)
  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  $lower = $Text.ToLowerInvariant()

  foreach ($term in $excludedRegionalTerms) {
    if ($lower.Contains($term) -and -not (Test-ContainsAny $Text $vietnamTerms)) {
      return $false
    }
  }

  $hasVietnam = Test-ContainsAny $Text $vietnamTerms
  $hasBusiness = Test-ContainsAny $Text $businessTerms
  return $hasVietnam -and $hasBusiness
}

function Get-InsightCategory {
  param([string]$Text)
  $lower = $Text.ToLowerInvariant()
  if ($lower -match "infrastructure|airport|metro|road|bridge|project") { return "Infrastructure" }
  if ($lower -match "retail|consumer|sales|services") { return "Consumer Demand" }
  if ($lower -match "fdi|investment|investor|certificate|campus|data center|ai") { return "Investment" }
  if ($lower -match "carbon|green|energy|esg") { return "Green Economy" }
  if ($lower -match "stock|gold|dong|bank|finance|market") { return "Finance / Markets" }
  if ($lower -match "property|real estate|office|industrial") { return "Property" }
  return "Vietnam Economy"
}

function Get-InsightSummary {
  param([string]$Title)
  $category = Get-InsightCategory $Title
  switch ($category) {
    "Infrastructure" { return "Infrastructure movement can affect office, retail, logistics, industrial, and property-entry decisions for new Vietnam entrants." }
    "Consumer Demand" { return "Consumer and service-sector signals help foreign brands judge whether Vietnam is worth testing city by city." }
    "Investment" { return "Investment activity is a useful signal for sectors attracting capital, partners, suppliers, and business-support demand." }
    "Green Economy" { return "Green-economy and compliance shifts can create opportunities for ESG, manufacturing, energy, and advisory-linked services." }
    "Finance / Markets" { return "Finance and market headlines help owners track confidence, currency pressure, consumer sentiment, and timing risk." }
    "Property" { return "Property and real-estate movement can affect office, retail, industrial, and workspace-entry planning." }
    default { return "Vietnam economic news selected for business owners considering market entry, partnerships, or local setup." }
  }
}

function Get-AnchorsFromHtml {
  param([string]$Html, [string]$BaseUrl)
  $anchors = New-Object System.Collections.Generic.List[object]
  $pattern = '<a\b(?<attrs>[^>]*)>(?<text>[\s\S]*?)</a>'
  foreach ($match in [regex]::Matches($Html, $pattern, "IgnoreCase")) {
    $attrs = $match.Groups["attrs"].Value
    $text = ConvertTo-PlainText $match.Groups["text"].Value
    $href = ""
    $title = ""
    if ($attrs -match 'href=["''](?<href>[^"'']+)["'']') { $href = $Matches.href }
    if ($attrs -match 'title=["''](?<title>[^"'']+)["'']') { $title = [System.Net.WebUtility]::HtmlDecode($Matches.title) }
    $label = if (-not [string]::IsNullOrWhiteSpace($title)) { $title.Trim() } else { $text }
    $url = ConvertTo-AbsoluteUrl $BaseUrl $href
    if (-not [string]::IsNullOrWhiteSpace($label) -and -not [string]::IsNullOrWhiteSpace($url)) {
      $anchors.Add([pscustomobject]@{ title = $label; url = $url })
    }
  }
  return $anchors
}

function Get-NewsItemsFromRss {
  param($Source)
  $results = New-Object System.Collections.Generic.List[object]
  if ([string]::IsNullOrWhiteSpace($Source.rss)) { return $results }

  try {
    $feed = Invoke-RestMethod -Uri $Source.rss -TimeoutSec 25
    foreach ($entry in $feed.rss.channel.item) {
      $title = ConvertTo-PlainText ([string]$entry.title)
      $description = ConvertTo-PlainText ([string]$entry.description)
      $combined = "$title $description"
      if (-not (Test-VietnamBusinessHeadline $combined $Source.name)) { continue }

      $results.Add([pscustomobject]@{
        category = Get-InsightCategory $combined
        title = $title
        summary = Get-InsightSummary $combined
        sourceName = [string]$Source.name
        url = [string]$entry.link
        publishedAt = [string]$entry.pubDate
      })
    }
  } catch {
    Write-Warning "RSS unavailable for $($Source.name): $($_.Exception.Message)"
  }

  return $results
}

function Get-NewsItemsFromHtml {
  param($Source)
  $results = New-Object System.Collections.Generic.List[object]
  if ([string]::IsNullOrWhiteSpace($Source.url)) { return $results }

  try {
    $html = (Invoke-WebRequest -Uri $Source.url -UseBasicParsing -TimeoutSec 25).Content
    foreach ($anchor in Get-AnchorsFromHtml $html $Source.url) {
      if ($anchor.title.Length -lt 18 -or $anchor.title.Length -gt 140) { continue }
      if ($anchor.title -eq "Hanoi Investment Promotion") { continue }
      if (-not (Test-VietnamBusinessHeadline $anchor.title $Source.name)) { continue }

      $results.Add([pscustomobject]@{
        category = Get-InsightCategory $anchor.title
        title = $anchor.title
        summary = Get-InsightSummary $anchor.title
        sourceName = [string]$Source.name
        url = $anchor.url
      })
    }
  } catch {
    Write-Warning "HTML unavailable for $($Source.name): $($_.Exception.Message)"
  }

  return $results
}

function Get-OpportunityType {
  param([string]$Text, [string]$DefaultType)
  $lower = $Text.ToLowerInvariant()
  if ($lower -match "franchise") { return "franchise" }
  if ($lower -match "office|property|retail space|warehouse|factory|lease|rent") { return "property" }
  if ($lower -match "investment|investor|funding|stake") { return "sale" }
  if ($DefaultType -match "franchise") { return "franchise" }
  return "sale"
}

function Get-OpportunityItems {
  param($Source)
  $results = New-Object System.Collections.Generic.List[object]
  if ([string]::IsNullOrWhiteSpace($Source.url)) { return $results }
  $terms = @("vietnam", "ho chi minh", "hanoi", "da nang", "business for sale", "franchise", "investment", "startup", "company", "restaurant", "manufacturing", "software", "retail", "cafe", "hotel", "spa")

  try {
    $html = (Invoke-WebRequest -Uri $Source.url -UseBasicParsing -TimeoutSec 25).Content
    foreach ($anchor in Get-AnchorsFromHtml $html $Source.url) {
      if ($anchor.title.Length -lt 14 -or $anchor.title.Length -gt 150) { continue }
      if (Test-ContainsAny $anchor.title $excludedOpportunityTerms) { continue }
      if (Test-ContainsAny $anchor.title $excludedOpportunityProfileTerms) { continue }
      if ($anchor.url -match "spain\.businessesforsale\.com") { continue }
      if (-not (Test-ContainsAny $anchor.title $terms)) { continue }

      $type = Get-OpportunityType $anchor.title $Source.type
      $category = if ($type -eq "franchise") { "Franchise" } elseif ($type -eq "property") { "Property / Workspace" } else { "Business For Sale" }
      $results.Add([pscustomobject]@{
        type = $type
        category = $category
        title = $anchor.title
        summary = "Automatically discovered public lead. Verify seller identity, financials, ownership, availability, and terms before presenting to any buyer."
        location = "Vietnam"
        price = "Check source"
        sourceName = [string]$Source.name
        url = $anchor.url
        verificationStatus = "Public source only"
      })
    }
  } catch {
    Write-Warning "Opportunity source unavailable for $($Source.name): $($_.Exception.Message)"
  }

  return $results
}

$insightItems = New-Object System.Collections.Generic.List[object]
foreach ($source in $config.newsSources) {
  $rssItems = Get-NewsItemsFromRss $source
  foreach ($item in $rssItems) { $insightItems.Add($item) }
  if ($rssItems.Count -lt 3) {
    foreach ($item in (Get-NewsItemsFromHtml $source)) { $insightItems.Add($item) }
  }
}

$seenInsight = @{}
$dedupedInsights = foreach ($item in $insightItems) {
  $key = (($item.title -replace "\s+", " ").Trim()).ToLowerInvariant()
  if (-not $seenInsight.ContainsKey($key)) {
    $seenInsight[$key] = $true
    $item
  }
}

if (@($dedupedInsights).Count -gt 0) {
  Write-JsonFile -Path $insightsPath -Payload ([pscustomobject]@{
    updatedAt = (Get-Date).ToString("o")
    items = @($dedupedInsights | Select-Object -First $InsightLimit)
  })
}

$opportunityItems = New-Object System.Collections.Generic.List[object]
foreach ($source in $config.opportunitySources) {
  foreach ($item in (Get-OpportunityItems $source)) { $opportunityItems.Add($item) }
}

$fallbackOpportunityItems = @(
  [pscustomobject]@{
    type = "sale"
    category = "Business For Sale"
    title = "Vietnam public acquisition listings"
    summary = "Automatically refreshed lead source. Use this as a discovery route only; seller claims, financials, ownership, and availability require direct verification."
    location = "Vietnam"
    price = "Varies"
    sourceName = "BusinessesForSale Vietnam"
    url = "https://www.businessesforsale.com/search/businesses-for-sale-in-vietnam"
    verificationStatus = "Public source only"
  },
  [pscustomobject]@{
    type = "sale"
    category = "Business / Investment"
    title = "Vietnam and regional deal-flow watch"
    summary = "Track business sale, investor, funding, and franchise signals. Use as a discovery route and verify directly before presenting to clients."
    location = "Vietnam / Southeast Asia"
    price = "Varies"
    sourceName = "Hola Advisory"
    url = "#contact"
    verificationStatus = "Curated only"
  },
  [pscustomobject]@{
    type = "franchise"
    category = "Franchise"
    title = "Franchise opportunity pipeline"
    summary = "Reserved for franchise leads from public platforms, chambers, brand submissions, and approved partner referrals."
    location = "Vietnam"
    price = "Case by case"
    sourceName = "Hola Advisory"
    url = "#contact"
    verificationStatus = "Curated only"
  },
  [pscustomobject]@{
    type = "property"
    category = "Property / Workspace"
    title = "Starter office and retail search"
    summary = "Workspace, virtual office, private office, and retail location routes for new Vietnam entrants."
    location = "Ho Chi Minh City"
    price = "On request"
    sourceName = "Hola Advisory"
    url = "#workspace"
    verificationStatus = "Owned / partner route"
  }
)

$seenOpportunity = @{}
$dedupedOpportunities = foreach ($item in $opportunityItems) {
  $key = (($item.title -replace "\s+", " ").Trim()).ToLowerInvariant()
  if (-not $seenOpportunity.ContainsKey($key)) {
    $seenOpportunity[$key] = $true
    $item
  }
}

if (@($dedupedOpportunities).Count -eq 0 -and (Test-Path -LiteralPath $opportunitiesPath)) {
  try {
    $existingOpportunities = Get-Content -Raw -LiteralPath $opportunitiesPath | ConvertFrom-Json
    if (@($existingOpportunities.items).Count -gt 0) {
      Write-Warning "No live opportunity items found. Keeping existing opportunity feed."
      Write-Host "Updated insights and opportunities JSON."
      exit 0
    }
  } catch {
    Write-Warning "Existing opportunity feed could not be reused: $($_.Exception.Message)"
  }
}

if (@($dedupedOpportunities).Count -eq 0) {
  $dedupedOpportunities = $fallbackOpportunityItems
} else {
  $dedupedOpportunities = @($dedupedOpportunities | Select-Object -First $OpportunityLimit) + $fallbackOpportunityItems
}

Write-JsonFile -Path $opportunitiesPath -Payload ([pscustomobject]@{
  updatedAt = (Get-Date).ToString("o")
  items = @($dedupedOpportunities | Select-Object -First $OpportunityLimit)
})

Write-Host "Updated insights and opportunities JSON."
