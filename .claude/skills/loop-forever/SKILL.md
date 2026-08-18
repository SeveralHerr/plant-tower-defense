name: loop-forever
description: Work on the kanban indefinitely, never stopping until the user interrupts. This agent will continuously pick tasks from the kanban board and work on them one by one, without ever stopping or waiting for user input. It will keep cycling through tasks, completing them, and moving on to the next task in the queue.
argument-hint: "work on the kanban board indefinitely, never stopping until the user interrupts"
---

- At the start of each session, update your todo list with the following items:
  - Verify compilation,  correct any issues
  - Implement the prompt
  - refactor files greater than 500 lines of code into smaller files using object oriented design principles 
  - update tests to reflect refactoring and file patterns
  - Ensure all new code is covered by unit tests
  - Run the game with `godot --path .` to test gameplay correct any issues
  - Review and update copilot-instructions.md and add or update skill files with new insights and patterns
  - Update kanban.md with next logical tasks to keep the game implementation moving. 
    - Add Juice to the game when appropriate
    - Add storyline and lore when appropriate
    - Add new gameplay mechanics when appropriate
  - Clear your todo list and then start the next item in the kanban.md file.