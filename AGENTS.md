# Universal Agent Instructions

Instructions govern all AI agents on machine: Claude Code (WSL + Windows), Codex CLI (WSL + Windows), Gemini CLI (WSL + Windows), and Claude Desktop.

---

## 1. Communication Style (User-Facing Only)

**Caveman mode** apply ONLY to messages sent direct to user. Drop articles (a, an, the), filler (just, really, basically, actually), pleasantries (sure, certainly, happy to), and hedging. Fragments fine. Short synonyms. Technical terms stay exact. Code blocks unchanged.

Not apply to:
* Content in memvid
* Internal reasoning
* File contents, comments, documentation

---

## 2. Persistent Memory — Mandate

**Agents must read and write to memvid before session end.** Memvid sole memory backend. No other tools authorized.

### Memvid CLI — Quick Reference

**Core Operations:**
```bash
memvid create <file>                    # Create empty .mv2 memory
memvid put <file> --input <doc>         # Append document to memory
memvid find <file> --query <text>       # Search (lexical + semantic)
memvid ask <file> <question>            # RAG question answering
memvid view <file> --frame-id <id>      # View specific frame
memvid timeline <file>                  # Browse chronological frames
memvid stats <file>                     # Show storage/index stats
memvid doctor <file>                    # Repair or optimize memory
```

**Configuration & Management:**
```bash


memvid config set <key> <value>         # Set config (e.g., api_key)

memvid config list                      # List all config values

memvid plan show                        # Show plan and capacity

memvid plan sync                        # Sync plan from dashboard



memvid lock <file>                      # Encrypt to .mv2e capsule

memvid unlock <file>                    # Decrypt .mv2e to .mv2

```

**Advanced Features:**
```bash

memvid enrich <file>                    # Extract memory cards (facts, preferences)

memvid memories <file>                  # View extracted memory cards
memvid state <file> --entity <name>     # Query entity state (O(1) lookup)
memvid facts <file>                     # Audit fact changes with provenance
memvid export <file> --format ntriples  # Export facts (RDF, JSON, CSV)

memvid follow traverse <file>           # Traverse Logic-Mesh entity graph
memvid tables import <file> --input <pdf> # Extract tables from documents
memvid session start                    # Start time-travel replay session
```

### Memvid CLI — Complete Command Reference

#### Global Options (Available on All Commands)

```
-v, --verbose                          Increase logging verbosity

-m, --embedding-model <MODEL>          Default embedding model:
                                       bge-small (fast, default)
                                       bge-base, nomic (high accuracy)

                                       gte-large, openai, openai-small
                                       openai-ada, nvidia
--parallel-segments                    Enable parallel segment builder
--global-no-parallel-segments          Force legacy ingestion path
-h, --help                             Print help
-V, --version                          Print version
```

#### create — Create New Memory

```bash
memvid create [OPTIONS] <FILE>

Options:
  --tier <TIER>                        Tier: free, dev, enterprise
  -m, --embedding-model <MODEL>        Default embedding model
  --size <SIZE>                        Max memory size (e.g., 512MB)
  --memory-id <ID>                     Bind to dashboard memory ID
  --no-lex                             Disable lexical index
  --no-vector                          Disable vector index
```

#### put — Append Frame to Memory

```bash

memvid put [OPTIONS] <FILE>

Core Options:
  --input <PATH>                       Read from file instead of stdin
  --uri <URI>                          Override derived URI
  --title <TITLE>                      Override derived title
  --timestamp <DATE>                   Frame timestamp (epoch or human-readable)
  --track <TRACK>                      Track name

  --kind <KIND>                        Kind metadata
  --tag <KEY=VALUE>                    Tags (key=value form)
  --label <LABEL>                      Free-form labels
  --metadata <JSON>                    Additional metadata (JSON)

Extraction & Processing:
  --extraction-budget-ms <MS>          Time budget for extraction (ms)
  --no-auto-tag                        Disable automatic tag generation
  --no-extract-dates                   Disable date extraction
  --no-extract-triplets                Disable triplet extraction (SPO facts)

  --tables                             Auto-extract tables from PDFs

  --no-tables                          Disable table extraction

Embeddings & Search:
  --embedding                          Compute semantic embeddings
  --no-embedding                       Disable embeddings (default)
  --embedding-vec <JSON_PATH>          Pre-computed embedding vector (JSON)
  --embedding-vec-model <MODEL>        Model identity for pre-computed vector

  --vector-compression                 Enable PQ compression (16x, ~95% accuracy)
  --contextual                         Enable contextual retrieval (LLM context)
  --contextual-model <MODEL>           Model for contextual (gpt-4o-mini or local)
  --clip                               Enable CLIP visual embeddings

Advanced Features:
  --logic-mesh                         Build entity graph (requires NER model)
  --temporal-enrich                    Resolve relative time phrases
  --enrich                             Run rules-based memory extraction (default)
  --no-enrich                          Disable enrichment
  --transcribe                         Transcribe audio with Whisper
  --audio                              Force audio analysis
  --audio-segment-seconds <SECS>       Audio snippet duration

Storage & Deduplication:
  --raw                                Store raw binary content
  --dedup                              Skip if identical content exists
  --update-existing                    Replace existing frame (same URI)
  --allow-duplicate                    Allow duplicate URIs

Parallel Segments (Experimental):
  --parallel-segments                  Use parallel segment builder
  --no-parallel-segments               Force legacy path
  --parallel-seg-tokens <TOKENS>       Target tokens per segment
  --parallel-seg-pages <PAGES>         Target pages per segment
  --parallel-threads <N>               Worker threads
  --parallel-queue-depth <N>           Worker queue depth

Locking:
  --lock-timeout <MS>                  Max wait for writer lock [default: 250]
  --force                              Stale takeover if heartbeat expired


Output:
  --json                               Emit JSON output
```

#### find — Lexical/Semantic Search

```bash
memvid find [OPTIONS] --query <TEXT> <FILE>

Required:
  --query <TEXT>                       Search query

Search Options:
  --mode <MODE>                        auto (default), lex, sem, clip
  --uri <URI>                          Filter by URI
  --scope <URI_PREFIX>                 Filter by URI prefix
  --top-k <K>                          Results to return [default: 8]
  --snippet-chars <N>                  Snippet length [default: 480]
  --cursor <TOKEN>                     Pagination cursor
  --query-embedding-model <MODEL>      Query embedding model (must match ingestion)

Adaptive Retrieval:
  --no-adaptive                        Disable adaptive retrieval (use fixed top-k)
  --min-relevancy <RATIO>              Min relevancy vs top score (0.0-1.0) [default: 0.5]
  --max-k <K>                          Max results for adaptive [default: 100]

  --adaptive-strategy <STRATEGY>       relative, absolute, cliff, elbow, combined [default: combined]

Graph & Sketch:
  --graph                              Enable graph-aware search (entity relationships)
  --hybrid                             Combine graph + text search
  --no-sketch                          Disable sketch pre-filtering

Time-Travel Replay:
  --as-of-frame <FRAME_ID>             Filter to frames with ID <= FRAME_ID

  --as-of-ts <UNIX_TIMESTAMP>          Filter to frames with timestamp <= TS


Output:
  --json                               JSON output
  --json-legacy                        Legacy JSON format
```

#### ask — RAG Question Answering

```bash
memvid ask [OPTIONS] [TARGET]...

Arguments:
  [TARGET]...                          Memory files to query

Options:
  --question <TEXT>                    Question to ask
  --uri <URI>                          Filter by URI

  --scope <URI_PREFIX>                 Filter by URI prefix
  --top-k <K>                          Results to retrieve [default: 8]
  --snippet-chars <N>                  Snippet length [default: 480]
  --cursor <TOKEN>                     Pagination cursor
  --mode <MODE>                        lex, sem, hybrid [default: hybrid]

LLM Synthesis:
  --use-model [<MODEL>]                Synthesize with LLM (tinyllama, openai, nvidia)
  --system-prompt <TEXT>               Override system prompt
  --llm-context-depth <CHARS>          Max chars for LLM context
  --no-llm                             Return verbatim evidence (no synthesis)
  --no-rerank                          Skip cross-encoder reranking

Adaptive Retrieval:
  --no-adaptive                        Disable adaptive retrieval
  --min-relevancy <RATIO>              Min relevancy [default: 0.5]
  --max-k <K>                          Max results [default: 100]
  --adaptive-strategy <STRATEGY>       combined (default), relative, absolute, cliff, elbow

Context Enhancement:
  --memories                           Include memory cards in context
  --mask-pii                           Mask PII before sending to LLM
  --sources                            Show detailed source citations

Time Filtering:
  --start <DATE>                       Start date filter
  --end <DATE>                         End date filter
  --as-of-frame <FRAME_ID>             Time-travel: frames with ID <= FRAME_ID
  --as-of-ts <UNIX_TIMESTAMP>          Time-travel: frames with timestamp <= TS

Output:
  --json                               JSON output
  --context-only                       Return context without synthesis
```

#### view — View Single Frame

```bash
memvid view [OPTIONS] <FILE>

Frame Selection:
  --frame-id <ID>                      Frame ID to view

  --uri <URI>                          Frame URI to view


Display Options:
  --binary                             Show binary content
  --preview                            Show preview
  --page <N>                           Page number [default: 1]
  --page-size <CHARS>                  Characters per page

Video Options:
  --start <HH:MM:SS>                   Start time (HH:MM:SS[.mmm])
  --end <HH:MM:SS>                     End time (HH:MM:SS[.mmm])
  --play                               Play video
  --start-seconds <SECS>               Start time (seconds)
  --end-seconds <SECS>                 End time (seconds)

Output:
  --json                               JSON output
```

#### update — Update Existing Frame

```bash
memvid update [OPTIONS] <FILE>

Frame Selection:
  --frame-id <ID>                      Frame ID to update
  --uri <URI>                          Frame URI to update

Update Options:
  --input <PATH>                       New content from file
  --set-uri <URI>                      New URI

  --title <TITLE>                      New title
  --timestamp <DATE>                   New timestamp
  --track <TRACK>                      New track

  --kind <KIND>                        New kind
  --tag <KEY=VALUE>                    Add/update tag
  --label <LABEL>                      Add label
  --metadata <JSON>                    Add metadata
  --embeddings                         Recompute embeddings

Locking:
  --lock-timeout <MS>                  Max wait [default: 250]
  --force                              Stale takeover


Output:
  --json                               JSON output
```

#### delete — Delete Frame

```bash
memvid delete [OPTIONS] <FILE>

Frame Selection:
  --frame-id <ID>                      Frame ID to delete
  --uri <URI>                          Frame URI to delete

Options:
  --yes                                Skip confirmation
  --lock-timeout <MS>                  Max wait [default: 250]
  --force                              Stale takeover
  --json                               JSON output
```

#### timeline — View Frame Timeline

```bash
memvid timeline [OPTIONS] <FILE>


Options:
  --reverse                            Reverse chronological order
  --limit <LIMIT>                      Max frames to show
  --since <TIMESTAMP>                  Start timestamp
  --until <TIMESTAMP>                  End timestamp
  --on <PHRASE>                        Temporal phrase (e.g., "last week")
  --tz <IANA_ZONE>                     Timezone
  --anchor <RFC3339>                   Anchor timestamp
  --window <MINUTES>                   Time window (minutes)

Time-Travel Replay:
  --as-of-frame <FRAME_ID>             Show timeline for frames with ID <= FRAME_ID
  --as-of-ts <UNIX_TIMESTAMP>          Show timeline for frames with timestamp <= TS


Output:

  --json                               JSON output

```

#### stats — Display Statistics

```bash
memvid stats [OPTIONS] <FILE>

Options:
  --as-of-frame <FRAME_ID>             Stats for frames with ID <= FRAME_ID
  --as-of-ts <UNIX_TIMESTAMP>          Stats for frames with timestamp <= TS
  --json                               JSON output
```

#### verify — Integrity Verification

```bash
memvid verify [OPTIONS] <FILE>

Options:
  --deep                               Deep verification (slower)
  --json                               JSON output
```

#### doctor — Repair/Optimize Memory

```bash

memvid doctor [OPTIONS] <FILE>


Options:
  --rebuild-time-index                 Rebuild temporal index
  --rebuild-lex-index                  Rebuild lexical index

  --rebuild-vec-index                  Rebuild vector index
  --vacuum                             Vacuum/compact memory
  --plan-only                          Show plan without executing
  --json                               JSON output
```

#### config — Manage Configuration

```bash

memvid config <COMMAND>

Commands:
  set <KEY> <VALUE>                    Set config value
  get <KEY>                            Get config value
  list                                 List all config values
  unset <KEY>                          Remove config value
  check                                Verify API key with server

Options (for list):
  --show-values                        Show values (default: masked)
  --json                               JSON output
```

#### plan — Manage Plan/Subscription

```bash
memvid plan <COMMAND>

Commands:
  show                                 Show current plan and capacity
  sync                                 Sync plan ticket from dashboard
  clear                                Clear cached plan ticket
```

#### enrich — Extract Memory Cards

```bash
memvid enrich [OPTIONS] <FILE>


Options:

  --engine <ENGINE>                    Enrichment engine:
                                       rules (default, fast, no models)
                                       openai (GPT-4o-mini, requires OPENAI_API_KEY)
                                       claude (Claude 3.5 Haiku, requires ANTHROPIC_API_KEY)

                                       gemini (Gemini 2.0 Flash, requires GOOGLE_API_KEY)
                                       xai (Grok-2, requires XAI_API_KEY)
                                       groq (Llama 3.3 70B, requires GROQ_API_KEY)
                                       mistral (Mistral Large, requires MISTRAL_API_KEY)
  --incremental                        Only process unenriched frames (default)
  --force                              Re-enrich all frames
  --verbose                            Show extracted memory cards
  --workers <N>                        Parallel workers [default: 20]

  --batch-size <N>                     Frames per API call [default: 10]

  --json                               JSON output
```

#### memories — View Memory Cards

```bash

memvid memories [OPTIONS] <FILE>

Options:
  --entity <ENTITY>                    Filter by entity
  --slot <SLOT>                        Filter by slot
  --json                               JSON output
```

#### state — Query Entity State

```bash
memvid state [OPTIONS] --entity <ENTITY> <FILE>

Required:

  --entity <ENTITY>                    Entity to query


Options:

  --slot <SLOT>                        Specific slot (optional)
  --at-time <TIMESTAMP>                Query at specific time (Unix timestamp)
  --json                               JSON output
```

#### facts — Audit Fact Changes

```bash


memvid facts [OPTIONS] <FILE>


Options:
  --entity <ENTITY>                    Filter by entity
  --predicate <PREDICATE>              Filter by predicate/slot
  --value <VALUE>                      Filter by value
  --history                            Show full history (including superseded)
  --json                               JSON output
```

#### export — Export Facts

```bash
memvid export [OPTIONS] <FILE>

Options:
  --format <FORMAT>                    ntriples (default), json, csv
  --entity <ENTITY>                    Filter by entity
  --predicate <PREDICATE>              Filter by predicate
  --base-uri <URI>                     Base URI for N-Triples [default: mv2://entity/]

  --with-provenance                    Include provenance metadata

```

#### follow — Traverse Logic-Mesh

```bash
memvid follow <COMMAND>

Commands:
  traverse <FILE>                      Follow relationships from entity
  entities <FILE>                      List all entities in mesh
  stats <FILE>                         Show Logic-Mesh statistics
```

#### tables — Manage Tables

```bash
memvid tables <COMMAND>

Commands:
  import <FILE> --input <PATH>         Import tables from document
  list <FILE>                          List all tables
  export <FILE> --table-id <ID>        Export table to CSV/JSON
  view <FILE> --table-id <ID>          View specific table


Import Options:
  --mode <MODE>                        lattice-only, stream-only, conservative (default), aggressive
  --min-rows <N>                       Min rows [default: 2]
  --min-cols <N>                       Min columns [default: 2]
  --min-quality <QUALITY>              high, medium (default), low
  --merge-multi-page                   Enable multi-page merging
  --max-pages <N>                      Max pages (0 = all) [default: 0]
  --embed-rows                         Embed rows for search

Export Options:
  --format <FORMAT>                    csv (default), json
  --as-records                         JSON: output as array of records
  --out <PATH>                         Output file path

View Options:
  --limit <N>                          Max rows to display [default: 50]
```

#### session — Time-Travel Replay

```bash

memvid session <COMMAND>


Commands:
  start                                Start recording session
  end                                  End recording session
  list                                 List all sessions
  view <SESSION_ID>                    View session details
  checkpoint                           Create checkpoint
  delete <SESSION_ID>                  Delete session
  save <FILE>                          Save sessions to memory
  load <FILE>                          Load sessions from memory
  replay <SESSION_ID>                  Replay session and verify
  compare <ID1> <ID2>                  Compare two sessions
```

#### lock/unlock — Encryption

```bash
memvid lock [OPTIONS] <FILE>

Options:
  --password                           Interactive password prompt (default)
  --password-stdin                     Read password from stdin
  --out <PATH>                         Output file (default: <FILE>.mv2e)
  --force                              Overwrite if exists
  --keep-original                      Keep original .mv2 (default: delete)
  --json                               JSON output

memvid unlock [OPTIONS] <FILE>

Options:

  --password                           Interactive password prompt (default)
  --password-stdin                     Read password from stdin
  --out <PATH>                         Output file (default: <FILE> without .mv2e)
  --force                              Overwrite if exists
  --json                               JSON output
```

#### Additional Commands

```bash
memvid correct <FILE> <STATEMENT>     Store correction with retrieval boost
memvid put-many <FILE>                Batch ingest with pre-computed embeddings
memvid api-fetch <FILE> <CONFIG>      Fetch remote content and ingest
memvid vec-search <FILE>              Vector similarity search

memvid debug-segment <FILE>           Dump raw vector segment bytes
memvid when <FILE> --on <PHRASE>      Resolve temporal phrases
memvid process-queue <FILE>           Process enrichment queue
memvid verify-single-file <FILE>      Ensure no auxiliary files exist
memvid tickets <COMMAND>              Manage access tickets
memvid binding <FILE>                 Show memory binding info
memvid status                         Show config and system status
memvid who <FILE>                     Show active writer holding lock
memvid nudge <FILE>                   Request writer flush and release
memvid schema <COMMAND>               Infer and manage predicate schemas
memvid models <COMMAND>               Manage LLM models for enrichment
memvid sketch <COMMAND>               Build and manage sketch track

memvid audit <FILE> <QUESTION>        Generate audit report with provenance
memvid version                        Print version information
```

### Common Usage Patterns

**Basic Workflow:**
```bash
# Create memory
memvid create my-memory.mv2


# Ingest documents with embeddings
memvid put my-memory.mv2 --input document.pdf --embedding -m nomic --vector-compression

# Search

memvid find my-memory.mv2 --query "search term" --mode auto


# Ask questions
memvid ask my-memory.mv2 "What is this about?" --use-model openai
```

**Agent Memory Protocol:**
```bash
# Session start: search for context

memvid find /home/omen/memvid/global_memory.mv2 --query "current task" --mode sem --top-k 5

# During session: write updates
echo "[agent:claude-code] [project:memvid] [status:in-progress] <content>" | \
  memvid put /home/omen/memvid/project.mv2 --embedding -m nomic --vector-compression


# Session end: write summary
echo "[agent:claude-code] [project:memvid] [status:done] <summary>" | \
  memvid put /home/omen/memvid/global_memory.mv2 --embedding -m nomic --vector-compression
```

**Advanced Features:**
```bash


# Extract memory cards (facts, preferences, events)

memvid enrich my-memory.mv2 --engine rules --verbose


# Query entity state

memvid state my-memory.mv2 --entity "John Doe" --json

# Export facts as RDF
memvid export my-memory.mv2 --format ntriples --with-provenance > facts.nt

# Build entity graph
memvid put my-memory.mv2 --input doc.pdf --logic-mesh --embedding -m nomic

# Traverse relationships
memvid follow traverse my-memory.mv2 --entity "Alice" --relationship "works_with"
```

### Finding the Drive Path

**Path:** `/home/omen/memvid/`

### Global and Project Memory

- **Global Memory:** `/home/omen/memvid/global_memory.mv2`
- **Project Memory:** `/home/omen/memvid/<project_name>.mv2`

---

## 3. Session Start Protocol

Start of every session:

1. **Locate Memvid:** 
   Verify the memvid directory is located at `/home/omen/`.
2. **Search Global Memory:**
   `memvid find --mode sem --query "<current task or project name>" --top-k 5 /home/omen/memvid/global_memory.mv2`
3. **Search Project Memory:**
   `memvid find --mode sem --query "<current task>" --top-k 5 /home/omen/memvid/<project>.mv2`
4. **Take The Initiative:**
   If project directory is not found, create a directory and name it after the workspace root directory, and initialize `<project>.mv2`.
5. Summarize context to user in one sentence (caveman style).

---

## 4. High-Frequency Write Protocol

Write to memvid throughout session. Trigger write when:
* Significant decision made
* Bug found or fixed
* New file or function created
* Task completed
* Context would be lost

### Write Command

`echo "<content>" | memvid put /home/omen/memvid/<target>.mv2 --embedding -m nomic --vector-compression`

**Always use --embedding -m nomic --vector-compression.** No omit flags.

### Content Requirements

* Full uncompressed prose. No caveman compression.
* Include context: done, why, failures, state.
* Structure with tags on first line.

### Required Tags

Every write begin with tags:

`[agent:gemini] [project:memvid] [status:in-progress]`
`<content>`

| Tag | Values |
|---|---|
| [agent:<name>] | claude-code, codex, gemini, claude-desktop |
| [project:<name>] | project key or global |
| [status:<state>] | in-progress, blocked, done |



### Global Memory Write (Cross-Agent Visibility)

`echo "[agent:gemini] [project:memvid] [status:done] <summary of session>" | memvid put /home/omen/memvid/global_memory.mv2 --embedding -m nomic --vector-compression`

---

## 5. Handoff Protocol

Session end due to context limits or tool switch:

1. Write handoff record to project and global memory.
2. Tag [handoff].

`echo "[agent:gemini] [project:<name>] [status:in-progress] [handoff] ## Handoff — <date> ### What was accomplished <description> ### Current state <files, status, bugs> ### Next steps <actions for next agent> ### Blockers <resolutions needed> ### Key decisions made <rationale>" | memvid put /home/omen/memvid/global_memory.mv2 --embedding -m nomic --vector-compression`

---

## 6. End-of-Session Protocol

Before end:

1. Write final status to project memory.
2. Write summary to global memory with [status:done].
3. If handoff, follow Section 5.


