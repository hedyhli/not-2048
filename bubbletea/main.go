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
	columns [COLS][ROWS+1]block
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
	var columns [COLS][ROWS+1]block;
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
	case "1": c = 0
	case "2": c = 1
	case "3": c = 2
	case "4": c = 3
	case "5": c = 4
	default:
		return false
	}

	if m.nextRow[c] == ROWS && m.columns[c][m.nextRow[c]-1] != m.next {
		m.msg = "naughty :/"
		return false
	}
	m.columns[c][m.nextRow[c]] = m.next
	m.total += 1
	m.nextRow[c] += 1
	m.moves += 1

	// TODO: Move this to Update instead.
	// It will return a tick, that does more collapsing
	// In collapse, update a `m.multi` and/or collapse-area info
	// for View to display.
	// Interval something around 500ms
	for m.collapse(m.nextRow[c]-1, c) {
	}

	return true
}

func (m *model) collapse(r int, c int) bool {
	this := m.columns[c][r]

	var up, left, right block
	if (r > 0) {
		up = m.columns[c][r-1]
	}
	if (c > 0) {
		left = m.columns[c-1][r]
	}
	if (c < COLS-1) {
		right = m.columns[c+1][r]
	}

	// Callapse sideways
	if (left == this && right == this) {
		// 4 8 4  r-1
		// 2 2 2  r
		// 8   4  r+1
		//
		// 4 8 4
		// 8 8 4
		//
		// 4 32 8?
		// TODO
		m.total -= 2
		// 2 2 2 => 8
		// 4 4 4 => 16
		// ...
		m.columns[c][r] = this << 2

		// left disappears
		for i := r; i < COLS; i += 1 {
			m.columns[c-1][i] = m.columns[c-1][i+1];
		}
		m.nextRow[c-1] -= 1;
		// right disappears
		for i := r; i < COLS; i += 1 {
			m.columns[c+1][i] = m.columns[c+1][i+1];
		}
		m.nextRow[c+1] -= 1;
		// Collapse left
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
		case "1", "2", "3", "4", "5":
			if m.putBlock(msg.String()) {
				m.getNext()
				m.msg = ""

				if m.total == COLS * ROWS {
					end := true
					for c := 0; c < COLS; c += 1 {
						if m.columns[c][ROWS-1] == m.next {
							end = false
							break
						}
					}
					if end {
						m.msg = "lol try harder next time"
						return m, tea.Quit
					}
				}
			}
		case "ctrl+c", "q":
			m.msg = "byee"
			return m, tea.Quit
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

	// TODO: Unicode column chars
	// Top and bottom row padding
	// [background] colors
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
	s += "\n\n"

	return
}

func main() {
	program := tea.NewProgram(initial())
	if _, err := program.Run(); err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}
