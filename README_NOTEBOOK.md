# Jupyter Notebook Guide - AI Trojan Generation

## Overview

This project includes a **Jupyter Notebook** (`Generate_Trojans_with_ChatGPT.ipynb`) that makes it easy to understand and use ChatGPT API for Trojan generation.

## Why Use a Notebook?

### Advantages

1. **Interactive**: Run code step-by-step
2. **Educational**: Markdown explanations between code
3. **Visual**: See outputs immediately
4. **Documented**: Instructions built into the notebook
5. **Easy to understand**: Clear structure and flow

### Structure

The notebook is organized into sections:
- **Setup**: Install packages, set API key
- **Task 1**: AES Key Leakage Trojan
- **Task 2**: AES DoS Trojan
- **Task 3**: Wishbone Bus DoS Trojan
- **Task 4**: UART Functionality Change Trojan
- **Review**: Check generated files and logs

## How to Use

### Step 1: Install Jupyter

```bash
pip3 install jupyter notebook
```

### Step 2: Launch Jupyter

```bash
cd CSAW_HT_Challenge
jupyter notebook
```

This will open Jupyter in your browser.

### Step 3: Open the Notebook

1. Click on `Generate_Trojans_with_ChatGPT.ipynb`
2. The notebook will open with all cells visible

### Step 4: Set Your API Key

In the first code cell, set your ChatGPT API key:

```python
# Option 1: Get from environment variable (recommended)
API_KEY = os.getenv('OPENAI_API_KEY')

# Option 2: Set directly (less secure)
# API_KEY = 'sk-your-actual-api-key-here'
```

### Step 5: Run Cells

1. **Run Setup cells**: Install packages, set API key, import libraries
2. **Run Task cells**: Generate Trojans for each task
3. **Run Review cells**: Check generated files

**To run a cell**: Click on it and press `Shift+Enter`

**To run all cells**: `Cell` → `Run All`

## Notebook Structure

### Markdown Cells

These contain:
- **Explanations**: What we're doing and why
- **Instructions**: Step-by-step guidance
- **Specifications**: What each Trojan should do

### Code Cells

These contain:
- **Setup code**: Install packages, set API key
- **Helper functions**: Extract code, save logs
- **Generation code**: Call ChatGPT API
- **Review code**: Check results

## What Each Section Does

### Setup Section

1. **Install packages**: `pip install openai`
2. **Set API key**: Get from environment or set directly
3. **Import libraries**: OpenAI, json, os, etc.
4. **Define helpers**: Functions to extract code and save logs

### Task Sections (1-4)

For each task:
1. **Read original RTL**: Load the Verilog file
2. **Build prompt**: Create comprehensive prompt for ChatGPT
3. **Call API**: Send prompt to ChatGPT and get response
4. **Save files**: Save modified RTL and AI log

### Review Section

1. **Check files**: Verify all files were generated
2. **View logs**: Look at AI interaction logs
3. **Summary**: See what was accomplished

## Example: Running Task 1

### Step 1: Read Original RTL

```python
task1_rtl_file = "task1_aes_key_leakage/rtl/aes.v"
with open(task1_rtl_file, 'r') as f:
    task1_original_rtl = f.read()
```

**Output**: `✓ Read 12345 bytes from task1_aes_key_leakage/rtl/aes.v`

### Step 2: Build Prompt

```python
task1_prompt = f"""
You are an expert hardware security engineer...
[Complete prompt with original RTL code and specifications]
"""
```

**Output**: `✓ Prompt created (45678 characters)`

### Step 3: Call ChatGPT API

```python
response = client.chat.completions.create(
    model="gpt-4",
    messages=[...],
    temperature=0.3,
    max_tokens=8000
)
```

**Output**: `✓ Received response from ChatGPT (5678 characters)`

### Step 4: Save Files

```python
# Save modified RTL
with open("task1_aes_key_leakage/rtl/aes_trojan.v", 'w') as f:
    f.write(modified_code)

# Save AI log
save_ai_log("task1_aes_key_leakage", prompt, response, metadata)
```

**Output**: 
```
✓ Saved modified RTL to task1_aes_key_leakage/rtl/aes_trojan.v
✓ Saved AI log to task1_aes_key_leakage/ai/task1_20250101_120000.json
```

## Understanding the Output

### Code Cell Outputs

Each code cell shows:
- **Status messages**: ✓ Success, ✗ Error, ⚠ Warning
- **File information**: Sizes, line counts
- **API information**: Response lengths, token usage
- **File paths**: Where files were saved

### Markdown Cells

These explain:
- **What we're doing**: Current step
- **Why it matters**: Purpose and importance
- **How it works**: Technical details
- **What to expect**: Expected outputs

## Tips for Using the Notebook

### 1. Run Cells Sequentially

- Don't skip cells
- Run them in order
- Wait for each to complete

### 2. Check Outputs

- Read status messages
- Verify files were created
- Check for errors

### 3. Review Logs

- Look at AI interaction logs
- Understand what was asked
- See what was generated

### 4. Test Generated Code

- Compile the generated RTL
- Create testbenches
- Verify Trojans work

## Troubleshooting

### "ModuleNotFoundError: No module named 'openai'"

**Solution**: Run the install cell:
```python
!pip install openai
```

### "OPENAI_API_KEY not set"

**Solution**: Set it in the first code cell:
```python
API_KEY = 'sk-your-key-here'
```

### "File not found"

**Solution**: Run setup script first:
```bash
./setup_original_rtl.sh
```

### "API rate limit exceeded"

**Solution**: Wait a few minutes and try again

## Advantages Over Python Scripts

### 1. Better Documentation

- Markdown cells explain everything
- Code cells are separated by explanations
- Easy to understand flow

### 2. Interactive Execution

- Run cells one at a time
- See outputs immediately
- Debug easily

### 3. Visual Feedback

- See file sizes
- See response lengths
- See token usage

### 4. Educational Value

- Learn as you go
- Understand each step
- See what's happening

## Summary

The Jupyter notebook makes it **much easier** to:
- Understand how AI is used
- See step-by-step execution
- Review what was generated
- Learn from the process

**To use it:**
1. Install Jupyter: `pip3 install jupyter notebook`
2. Launch: `jupyter notebook`
3. Open: `Generate_Trojans_with_ChatGPT.ipynb`
4. Run cells: `Shift+Enter` on each cell
5. Review results: Check generated files and logs

The notebook is **self-documenting** - all instructions are built in!

