from src.core.ai_processor import AIProcessor


def main() -> None:
    processor = AIProcessor("test_user")
    print("Model loaded:", processor.is_trained)
    print("Feature count:", len(processor.features))
    if processor.is_trained:
        print("Model type:", type(processor.model))
    else:
        print("No persisted model found for this user.")


if __name__ == "__main__":
    main()
