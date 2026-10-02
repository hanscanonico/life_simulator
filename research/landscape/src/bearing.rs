//! Load-bearing bytes (`docs/studies/topless.md` §2.3; the topless-rise entry's
//! H-rise-code, 2026-10-02): the positions of a tape where most substitutions over the
//! 14-symbol alphabet leave it credited, on all six fixed sets, no rung as deep as a target.

use crate::depth::{depth_name, DepthScorer};
use crate::score::par_map;
use crate::tape::{hex, show, ALPHABET, FILLER};
use std::fmt::Write;

/// A position is load-bearing where at least this many of the 13 other symbols lose the
/// depth: "at least half", 7 of 13, as the study's `bearing` read it and the entry locks.
pub const LOSING_SUBSTITUTES: usize = 7;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Bearing {
    pub tape: Vec<u8>,
    pub depth: u32,
    /// Per position, how many of the 13 other symbols lose the depth.
    pub losses: Vec<usize>,
}

impl Bearing {
    pub fn positions(&self) -> Vec<usize> {
        (0..self.losses.len())
            .filter(|at| self.losses[*at] >= LOSING_SUBSTITUTES)
            .collect()
    }

    pub fn count(&self) -> usize {
        self.positions().len()
    }

    pub fn render(&self) -> String {
        let mut out = String::new();
        let marks: String = self
            .losses
            .iter()
            .map(|lost| {
                if *lost >= LOSING_SUBSTITUTES {
                    '^'
                } else {
                    ' '
                }
            })
            .collect();
        let _ = writeln!(
            out,
            "load-bearing bytes at depth {}: {}\n  {}\n  {}\n  {}",
            depth_name(self.depth),
            self.count(),
            show(&self.tape),
            marks.trim_end(),
            hex(&self.tape)
        );
        let positions: Vec<String> = self.positions().iter().map(|at| at.to_string()).collect();
        let _ = writeln!(out, "  positions {}", positions.join(" "));
        let losses: Vec<String> = self.losses.iter().map(|lost| lost.to_string()).collect();
        let _ = writeln!(out, "  losses of 13 per position {}", losses.join(" "));
        out
    }
}

/// The 13 symbols a position is substituted with: the alphabet but the byte's own symbol, a
/// byte outside the alphabet read as the generic no-op it stands for.
fn substitutes(byte: u8) -> impl Iterator<Item = u8> {
    let own = if ALPHABET.contains(&byte) {
        byte
    } else {
        FILLER
    };
    ALPHABET.into_iter().filter(move |symbol| *symbol != own)
}

/// Each position of `tape` against `depth`: a substitution loses the depth where the
/// mutant is credited, on all six sets, no rung `depth` deep or deeper.
pub fn load_bearing(tape: &[u8], scorer: &DepthScorer, depth: u32) -> Bearing {
    let positions: Vec<usize> = (0..tape.len()).collect();
    let losses = par_map(&positions, |at| {
        let mut mutant = tape.to_vec();
        substitutes(tape[*at])
            .filter(|symbol| {
                mutant[*at] = *symbol;
                scorer.solid(&mutant).depth() < Some(depth)
            })
            .count()
    });
    Bearing {
        tape: tape.to_vec(),
        depth,
        losses,
    }
}

/// The topless-rise entry's label for a child's first and last world, each its deepest solid
/// rung's depth and its dominant solver's load-bearing count: new code where the depth rose
/// and the count rose by 2 or more, co-option where the depth rose and the count did not.
pub fn rise_code(first: Option<(u32, usize)>, last: Option<(u32, usize)>) -> &'static str {
    let (Some((first_depth, first_count)), Some((last_depth, last_count))) = (first, last) else {
        return "unread (a world holds no rung by a tenth)";
    };
    if last_depth <= first_depth {
        "no rise in depth"
    } else if last_count >= first_count + 2 {
        "new code (depth rose, load-bearing bytes rose by 2 or more)"
    } else if last_count <= first_count {
        "co-option (depth rose, load-bearing bytes did not)"
    } else {
        "neither (depth rose, load-bearing bytes rose by 1)"
    }
}

#[cfg(test)]
pub(crate) mod tests {
    use super::*;
    use crate::score::tests::STACK_SOLVERS;
    use life_engine::bff;
    use life_engine::logic::LOGIC_TASKS;
    use life_engine::params::{LogicNand, Tasks};
    use life_engine::topless::Inputs;
    use life_engine::Params;

    /// Compiles a witness circuit of `research/minnand/data/witnesses*.txt` (the output
    /// node, then each gate's two operands, a base-36 digit a node, inputs first) to a
    /// straight-line tape, as the engine's `topless::tests::compile` does, but emitting the
    /// output once: every gate's value on a byte of its own left of the inputs; under the
    /// stack NAND a gate copies its first operand onto the byte right of its own, so `~`
    /// writes it. The code is returned unpadded.
    pub fn compile(inputs: Inputs, witness: &str) -> Vec<u8> {
        let nodes: Vec<usize> = witness
            .chars()
            .map(|node| node.to_digit(36).expect("a base-36 node") as usize)
            .collect();
        let n = inputs.count();
        let slot = |input: usize| match inputs {
            Inputs::Three => input,
            Inputs::Four => (input + 3) % 4,
        };
        let place = |node: usize| {
            if node < n {
                1 + slot(node)
            } else {
                7 + 2 * (node - n)
            }
        };
        let mut code = Vec::new();
        let (mut head0, mut head1) = (0, 0);
        let go = |code: &mut Vec<u8>, head: &mut usize, to: usize, ops: [u8; 2]| {
            while *head < to {
                code.push(ops[0]);
                *head += 1;
            }
            while *head > to {
                code.push(ops[1]);
                *head -= 1;
            }
        };
        let heads0 = [bff::HEAD0_LEFT, bff::HEAD0_RIGHT];
        let heads1 = [bff::HEAD1_LEFT, bff::HEAD1_RIGHT];
        for (gate, operands) in nodes[1..].chunks(2).enumerate() {
            let at = place(n + gate);
            go(&mut code, &mut head0, at - 1, heads0);
            go(&mut code, &mut head1, place(operands[0]), heads1);
            code.push(bff::COPY_TO_HEAD0);
            go(&mut code, &mut head1, place(operands[1]), heads1);
            code.push(bff::NAND);
            head0 = at;
        }
        go(&mut code, &mut head0, place(nodes[0]), heads0);
        code.push(bff::EMIT);
        code
    }

    pub type Witness = (Inputs, u16, u32, &'static str, &'static [usize]);

    /// Witnesses from `research/minnand/data` (the engine's `topless::tests::SOLVERS`): the
    /// ladder, the function, its depth, its circuit, and the positions of its compile that
    /// bear no depth.
    pub const WITNESSES: [Witness; 4] = [
        (Inputs::Three, 0xe8, 6, "8000111352647", &[]),
        (Inputs::Three, 0x96, 8, "a0103134526276789", &[]),
        (Inputs::Four, 0x0003, 7, "a00112245676899", &[48]),
        (Inputs::Four, 0x0001, 10, "d0011223345676899abcc", &[63]),
    ];

    pub fn stack_params(tasks: Tasks) -> Params {
        Params {
            tasks,
            logic_nand: LogicNand::Stack,
            ..Params::default()
        }
    }

    fn scorer(inputs: Inputs) -> DepthScorer {
        let tasks = match inputs {
            Inputs::Three => Tasks::Logic3,
            Inputs::Four => Tasks::Logic4,
        };
        DepthScorer::for_params(&stack_params(tasks)).unwrap()
    }

    /// Every byte of the study's shortest straight-line stack programs bears its depth, on
    /// both ladders, and none of the zero padding does. `<<{~!` is no shortest program: its
    /// first `<` is spare, since `<{~!` is credited a depth-1 rung too.
    #[test]
    fn every_byte_of_a_shortest_straight_line_program_bears_its_depth_and_no_padding_does() {
        for inputs in [Inputs::Three, Inputs::Four] {
            let scorer = scorer(inputs);
            for (rung, spelled) in STACK_SOLVERS.iter().enumerate() {
                let tape = crate::tape::parse(spelled, 32).unwrap();
                let depth = scorer.solid(&tape).depth().unwrap();
                assert_eq!(depth, LOGIC_TASKS[rung].nands, "{spelled}");
                let spare = if *spelled == "<<{~!" { 1 } else { 0 };
                assert_eq!(
                    load_bearing(&tape, &scorer, depth).positions(),
                    (spare..spelled.len()).collect::<Vec<_>>(),
                    "{inputs:?} {spelled}"
                );
            }
        }
    }

    /// The minimal NAND witnesses compiled straight-line, each gate on a byte of its own:
    /// every byte bears the depth but one head move of each four-input compile, which a
    /// substitution can re-point at an operand of equal effect, and no padding does.
    #[test]
    fn a_compiled_witness_bears_its_depth_on_its_code_alone() {
        for (inputs, function, depth, witness, spare) in WITNESSES {
            let scorer = scorer(inputs);
            let code = compile(inputs, witness);
            let mut tape = code.clone();
            tape.resize(code.len() + 16, 0);
            let solid = scorer.solid(&tape);
            assert!(solid.has(inputs.class_of(function)), "{witness}");
            assert_eq!(solid.depth(), Some(depth), "{witness}");
            let bearing = load_bearing(&tape, &scorer, depth);
            let expected: Vec<usize> = (0..code.len()).filter(|at| !spare.contains(at)).collect();
            assert_eq!(
                bearing.positions(),
                expected,
                "{witness}: {}",
                bearing.render()
            );
        }
    }

    #[test]
    fn the_pair_is_labelled_by_the_entrys_rule() {
        assert!(rise_code(Some((5, 14)), Some((9, 20))).starts_with("new code"));
        assert!(rise_code(Some((5, 14)), Some((9, 16))).starts_with("new code"));
        assert!(rise_code(Some((5, 14)), Some((9, 14))).starts_with("co-option"));
        assert!(rise_code(Some((5, 14)), Some((9, 12))).starts_with("co-option"));
        assert!(rise_code(Some((5, 14)), Some((9, 15))).starts_with("neither"));
        assert!(rise_code(Some((5, 14)), Some((5, 20))).starts_with("no rise"));
        assert!(rise_code(None, Some((5, 20))).starts_with("unread"));
    }

    #[test]
    fn a_byte_outside_the_alphabet_is_substituted_as_the_no_op() {
        assert_eq!(substitutes(b'<').count(), 13);
        assert_eq!(substitutes(FILLER).count(), 13);
        assert_eq!(
            substitutes(0x41).collect::<Vec<_>>(),
            substitutes(FILLER).collect::<Vec<_>>()
        );
    }

    #[test]
    fn the_reading_is_deterministic() {
        let (inputs, _, depth, witness, _) = WITNESSES[2];
        let mut tape = compile(inputs, witness);
        tape.resize(32, 0);
        let scorer = scorer(inputs);
        assert_eq!(
            load_bearing(&tape, &scorer, depth),
            load_bearing(&tape, &scorer, depth)
        );
    }
}
