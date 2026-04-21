# Moonshine Model Files

Drop the *small-streaming-en* model files here before building.

## Expected layout

```
Models/
└── small-streaming-en/
    ├── adapter.ort
    ├── cross_kv.ort
    ├── decoder_kv.ort
    ├── decoder_kv_with_attention.ort
    ├── encoder.ort
    ├── frontend.ort
    ├── streaming_config.json
    └── tokenizer.bin
```

## Fetch

```bash
pip install moonshine-voice
python -m moonshine_voice.download --language en --model-arch 4
```

Copy the folder contents (8 files) from the printed cache path into
`Sources/iMoonshine/Models/small-streaming-en/`.

## Swap model

Edit `MoonshineTranscriber.swift`:

```swift
private static let modelFolderName = "small-streaming-en"
private static let modelArch: ModelArch = .smallStreaming
```

Arch values: `.tiny`(0) `.base`(1) `.tinyStreaming`(2) `.baseStreaming`(3) `.smallStreaming`(4) `.mediumStreaming`(5)
