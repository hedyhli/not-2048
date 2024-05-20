package main

import (
	"fmt"
	"math/rand"
	"os"

	tea "github.com/charmbracelet/bubbletea"
)

const COLS = 5;
const ROWS = 5;

/// A single block with its value
type block int

type model struct {
	moves int
	/// List of columns
	columns [COLS][ROWS]block
	/// Index of next row in each column
	nextRow [COLS]int
	/// Current max rows of the columns
	rows int
	/// Block up next
	next block
	/// Block after next
	peek block
	maxBase int
	total int
	msg string
}

func initial() model {
	var columns [COLS][ROWS]block;
	return model{
		moves: 0,
		columns: columns,
		nextRow: [COLS]int{0, 0, 0, 0, 0},
		rows: 0,
		next: 2,
		peek: 4,
		total: 0,
		maxBase: 2,
		msg: "hi",
	}
}

func (m *model) getNext() {
	base := block(rand.Intn(m.maxBase - 1) + 1)
	m.next = m.peek
	m.peek = (1 << base)
}

func (m *model) putBlock(cs string) bool {
	c := 0
	switch cs {
	case "1":
		c = 0
	case "2":
		c = 1
	case "3":
		c = 2
	case "4":
		c = 3
	case "5":
		c = 4
	default:
		return false
	}

	if m.nextRow[c] == ROWS {
		m.msg = "naughty :/"
		return false
	}
	m.columns[c][m.nextRow[c]] = m.next
	m.total += 1
	m.nextRow[c] += 1
	m.moves += 1

	for m.collapse(m.nextRow[c]-1, c) {
	}

	return true
}

func (m *model) collapse(r int, c int) bool {
	this := m.columns[c][r]
	var up block
	if (r > 0) {
		up = m.columns[c][r-1]
	}

	// Collapse up
	if (this == up) {
		m.total -= 1
		m.columns[c][r] = 0
		m.columns[c][r-1] = this + up
		m.nextRow[c] -= 1

		if (this + up > (1 << m.maxBase)) {
			m.maxBase += 1
		}
		return true
	}
	return false
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.msg = "byee"
			return m, tea.Quit
		case "1", "2", "3", "4", "5":
			if m.putBlock(msg.String()) {
				m.getNext()
				m.msg = ""

				if m.total == COLS * ROWS {
					m.msg = "lol try harder next time"
					return m, tea.Quit
				}
			}
		default:
			m.msg = "what"
		}
	}

	return m, nil
}

func (m model) View() (s string) {
	s = "Help help\n\n"

	for c := 0; c < COLS; c += 1 {
		s += fmt.Sprintf("  %d    ", c+1)
	}
	s += "\n"

	for r := 0; r < ROWS; r += 1 {
		for c := 0; c < COLS; c += 1 {
			block := m.columns[c][r]
			if block == 0 {
				s += "      |"
			} else {
				s += fmt.Sprintf(" %4d |", block)
			}
		}
		s += "\n\n"
	}
	s += m.msg + "\n\n"
	s += fmt.Sprintf("moves: %d\n\n", m.moves)
	s += fmt.Sprintf(" [[ %d ]] %d", m.next, m.peek)

	return
}

func main() {
	program := tea.NewProgram(initial())
	if _, err := program.Run(); err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}
