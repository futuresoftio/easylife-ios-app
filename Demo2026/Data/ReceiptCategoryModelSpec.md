# ReceiptCategoryClassifier Model Spec

Use a bundled Create ML text classifier model named `ReceiptCategoryClassifier.mlmodel`.

## Training Data Format

Train the model from a CSV file with exactly two columns:

```csv
text,label
"flat white coffee","Food"
"uber trip airport","Transport"
```

- `text`: OCR-normalized receipt item text, lowercase is fine.
- `label`: one of the app's supported categories.

Supported labels:

- `Food`
- `Transport`
- `Groceries`
- `Entertainment`
- `Health`
- `Shopping`
- `Bills`
- `Education`
- `Personal Care`
- `Home`
- `Car service`
- `Other`

## Model Input and Output

The bundled model is expected to be a Natural Language text classifier that works with `NLModel`.

- Input: a single `String` receipt item text.
- Output: a predicted label string and label probabilities.

In app code:

- Resource name: `ReceiptCategoryClassifier`
- Accepted bundle resource: `ReceiptCategoryClassifier.mlmodel` or compiled `ReceiptCategoryClassifier.mlmodelc`

## Recommended Training Examples

- Train on short item-level OCR phrases, not full receipts.
- Include OCR noise variants such as `cofee`, `uberbv`, `supa market`.
- Add an `Other` class for lines that do not fit a known category.
- Keep labels balanced to avoid overpredicting common classes like `Food`.

## App Flow

1. Vision OCR extracts receipt text lines.
2. The parser finds candidate expense lines and amounts.
3. `ReceiptCategoryClassifier` predicts a category from the item title.
4. If the model is missing or confidence is low, the app falls back to keyword rules.

## Local Training Command

From the repository root, train and export the model with:

```bash
./Demo2026/Scripts/train_receipt_category_classifier.sh
```

Default output:

```text
Demo2026/Models/ReceiptCategoryClassifier.mlmodel
```

Optional arguments:

```bash
./Demo2026/Scripts/train_receipt_category_classifier.sh \
  --input Demo2026/Data/ReceiptCategoryTrainingTemplate.csv \
  --output Demo2026/Models/ReceiptCategoryClassifier.mlmodel \
  --author "Wei Lin" \
  --version "1.0" \
  --description "Receipt item category classifier"
```
