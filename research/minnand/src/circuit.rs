//! A NAND circuit: the inputs are nodes `0..inputs`, gate i is node `inputs + i` and reads
//! two earlier nodes (the same node twice is NOT), and any node may feed any number of gates.

use crate::tt::{self, Tt};

/// The node characters of the witness files: `0`–`9`, then `a`–`z`.
const DIGITS: &[u8] = b"0123456789abcdefghijklmnopqrstuvwxyz";

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Circuit {
    pub inputs: usize,
    pub gates: Vec<(u8, u8)>,
    pub output: u8,
}

impl Circuit {
    /// Every node's table, inputs first. `None` when a gate reads a node not yet computed.
    pub fn tables(&self) -> Option<Vec<Tt>> {
        let mut nodes: Vec<Tt> = (0..self.inputs)
            .map(|i| tt::input(self.inputs, i))
            .collect();
        for &(a, b) in &self.gates {
            let (a, b) = (a as usize, b as usize);
            if a >= nodes.len() || b >= nodes.len() {
                return None;
            }
            nodes.push(tt::nand(self.inputs, nodes[a], nodes[b]));
        }
        Some(nodes)
    }

    /// The function at the output node, `None` for an ill-formed circuit.
    pub fn eval(&self) -> Option<Tt> {
        self.tables()?.get(self.output as usize).copied()
    }

    pub fn cost(&self) -> usize {
        self.gates.len()
    }

    /// The circuit computing f's permutation `perm` (see [`tt::permute`]).
    pub fn permuted(&self, perm: &[usize]) -> Circuit {
        let map = |node: u8| {
            let node = node as usize;
            (if node < self.inputs { perm[node] } else { node }) as u8
        };
        Circuit {
            inputs: self.inputs,
            gates: self.gates.iter().map(|&(a, b)| (map(a), map(b))).collect(),
            output: map(self.output),
        }
    }

    /// `output` then each gate's two operands, one character a node: `5 0112 3`… is written
    /// `"5" + "01" + "12"`; the gates of the four-input tables reach node 4 + 15 = `j` at most.
    pub fn encode(&self) -> String {
        let digit = |n: u8| DIGITS[n as usize] as char;
        std::iter::once(digit(self.output))
            .chain(self.gates.iter().flat_map(|&(a, b)| [digit(a), digit(b)]))
            .collect()
    }

    pub fn decode(inputs: usize, text: &str) -> Option<Circuit> {
        let nodes: Vec<u8> = text
            .bytes()
            .map(|c| DIGITS.iter().position(|&d| d == c).map(|p| p as u8))
            .collect::<Option<_>>()?;
        let (&output, gates) = nodes.split_first()?;
        if gates.len() % 2 != 0 {
            return None;
        }
        Some(Circuit {
            inputs,
            gates: gates.chunks(2).map(|g| (g[0], g[1])).collect(),
            output,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn xor2() -> Circuit {
        // t = NAND(x, y); XOR = NAND(NAND(x, t), NAND(y, t))
        Circuit {
            inputs: 2,
            gates: vec![(0, 1), (0, 2), (1, 2), (3, 4)],
            output: 5,
        }
    }

    #[test]
    fn evaluates_xor() {
        assert_eq!(xor2().eval(), Some(0xC ^ 0xA));
    }

    #[test]
    fn rejects_forward_references() {
        let bad = Circuit {
            inputs: 2,
            gates: vec![(0, 3), (0, 1)],
            output: 3,
        };
        assert_eq!(bad.eval(), None);
    }

    #[test]
    fn encodes_and_decodes() {
        let c = xor2();
        assert_eq!(c.encode(), "501021234");
        assert_eq!(Circuit::decode(2, &c.encode()), Some(c));
    }

    #[test]
    fn permuting_the_circuit_permutes_its_function() {
        let andn = Circuit {
            inputs: 3,
            gates: vec![(1, 1), (0, 3), (4, 4)],
            output: 5,
        };
        let f = andn.eval().unwrap();
        for perm in tt::permutations(3) {
            assert_eq!(andn.permuted(&perm).eval(), Some(tt::permute(3, f, &perm)));
        }
    }
}
