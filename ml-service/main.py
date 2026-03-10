def main():
    print("Welcome to the Console Application!")
    print("-" * 40)
    
    while True:
        user_input = input("\nEnter a command (or 'exit' to quit): ").strip().lower()
        
        if user_input == "exit":
            print("Goodbye!")
            break
        elif user_input == "help":
            print("Available commands: help, hello, exit")
        elif user_input == "hello":
            name = input("What's your name? ")
            print(f"Hello, {name}!")
        else:
            print("Unknown command. Type 'help' for available commands.")

if __name__ == "__main__":
    main()