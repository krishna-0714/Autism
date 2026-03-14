from src.core.ai_processor import AIProcessor


def main() -> None:
    processor = AIProcessor("test_user")
    print("Model initialized as:", type(processor.model))

    # Trigger update with a tiny, valid sample set.
    processor.update_model(
        [
            [{"bssid": "00:11:22", "level": -55}],
            [{"bssid": "00:11:22", "level": -70}],
        ],
        ["Living Room", "Bedroom"],
    )
    print("Model updated! Model type:", type(processor.model))


if __name__ == "__main__":
    main()
