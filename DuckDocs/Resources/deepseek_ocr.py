#!/usr/bin/env python3
"""
DeepSeek OCR 2 - Screenshot to Markdown Documentation
Uses MLX-Community 4-bit quantized model for local inference on Apple Silicon
"""

import sys
import json
import argparse
from pathlib import Path

def check_dependencies():
    """Check if required packages are installed."""
    missing = []
    try:
        import mlx_lm
    except ImportError:
        missing.append("mlx-lm")
    try:
        from PIL import Image
    except ImportError:
        missing.append("pillow")

    if missing:
        print(json.dumps({
            "error": "missing_dependencies",
            "packages": missing,
            "install_command": f"pip install {' '.join(missing)}"
        }))
        sys.exit(1)

def analyze_image(image_path: str, prompt: str = None, max_tokens: int = 2048) -> str:
    """
    Analyze an image using DeepSeek OCR 2 model.

    Args:
        image_path: Path to the image file
        prompt: Custom prompt for analysis
        max_tokens: Maximum tokens to generate

    Returns:
        Generated text description/markdown
    """
    from mlx_lm import load, generate
    from PIL import Image

    # Default prompt for UI documentation
    if prompt is None:
        prompt = """Analyze this UI screenshot and generate markdown documentation.

Describe:
1. What UI elements are visible (buttons, menus, text fields, etc.)
2. The current state of the interface
3. Any text content visible
4. The layout and organization

Format your response as clean markdown suitable for documentation."""

    # Load model (will be cached after first load)
    model_id = "mlx-community/DeepSeek-OCR-2-4bit"

    try:
        model, tokenizer = load(model_id)
    except Exception as e:
        return json.dumps({
            "error": "model_load_failed",
            "message": str(e),
            "model": model_id
        })

    # Load and prepare image
    try:
        image = Image.open(image_path)
        if image.mode != "RGB":
            image = image.convert("RGB")
    except Exception as e:
        return json.dumps({
            "error": "image_load_failed",
            "message": str(e),
            "path": image_path
        })

    # Generate response
    try:
        response = generate(
            model,
            tokenizer,
            prompt=prompt,
            images=[image],
            max_tokens=max_tokens,
            verbose=False
        )
        return response
    except Exception as e:
        return json.dumps({
            "error": "generation_failed",
            "message": str(e)
        })

def main():
    parser = argparse.ArgumentParser(
        description="DeepSeek OCR 2 - Convert screenshots to markdown documentation"
    )
    parser.add_argument(
        "--image", "-i",
        required=True,
        help="Path to the image file"
    )
    parser.add_argument(
        "--prompt", "-p",
        default=None,
        help="Custom prompt for analysis"
    )
    parser.add_argument(
        "--max-tokens", "-t",
        type=int,
        default=2048,
        help="Maximum tokens to generate (default: 2048)"
    )
    parser.add_argument(
        "--check-deps",
        action="store_true",
        help="Check if dependencies are installed"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output result as JSON"
    )

    args = parser.parse_args()

    # Check dependencies if requested
    if args.check_deps:
        check_dependencies()
        print(json.dumps({"status": "ok"}))
        sys.exit(0)

    # Verify image exists
    if not Path(args.image).exists():
        error = {
            "error": "file_not_found",
            "path": args.image
        }
        print(json.dumps(error))
        sys.exit(1)

    # Check dependencies before running
    check_dependencies()

    # Analyze image
    result = analyze_image(
        image_path=args.image,
        prompt=args.prompt,
        max_tokens=args.max_tokens
    )

    # Output result
    if args.json:
        print(json.dumps({"result": result}))
    else:
        print(result)

if __name__ == "__main__":
    main()
