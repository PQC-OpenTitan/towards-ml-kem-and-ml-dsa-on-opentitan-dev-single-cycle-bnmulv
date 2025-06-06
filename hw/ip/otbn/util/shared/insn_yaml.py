# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
# Modified by Authors of "Towards ML-KEM & ML-DSA on OpenTitan" (https://eprint.iacr.org/2024/1192).
# Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors.


'''Support code for reading the instruction database in insns.yml'''

import itertools
import os
import re
from typing import Dict, List, Optional, Tuple, cast

from serialize.parse_helpers import (check_keys, check_str, check_bool,
                                     check_list, index_list, get_optional_str,
                                     load_yaml)

from .encoding import Encoding
from .encoding_scheme import EncSchemes
from .information_flow import InsnInformationFlow
from .isr import Isr, read_isrs, IsrMap, IsrMaps
from .lsu_desc import LSUDesc
from .operand import Operand
from .syntax import InsnSyntax


class Insn:
    def __init__(self,
                 yml: object,
                 encoding_schemes: Optional[EncSchemes],
                 isrs: Optional[IsrMaps]) -> None:
        yd = check_keys(yml, 'instruction',
                        ['mnemonic', 'operands'],
                        ['group', 'rv32i', 'uses_isr', 'synopsis',
                         'syntax', 'doc', 'errs', 'note',
                         'encoding', 'glued-ops',
                         'literal-pseudo-op', 'python-pseudo-op', 'lsu',
                         'straight-line', 'iflow'])

        self.mnemonic = check_str(yd['mnemonic'], 'mnemonic for instruction')

        what = 'instruction with mnemonic {!r}'.format(self.mnemonic)

        encoding_yml = yd.get('encoding')
        self.encoding = None
        if encoding_yml is not None:
            if encoding_schemes is None:
                raise ValueError('{} specifies an encoding, but the file '
                                 'didn\'t specify any encoding schemes.'
                                 .format(what))

            self.encoding = Encoding(encoding_yml,
                                     encoding_schemes, self.mnemonic)

        self.operands = [Operand(y, self.mnemonic, self.encoding, isrs)
                         for y in check_list(yd['operands'],
                                             'operands for ' + what)]
        self.name_to_operand = index_list('operands for ' + what,
                                          self.operands,
                                          lambda op: op.name)

        # The call to index_list has checked that operand names are distinct.
        # We also need to check that no operand abbreviation clashes with
        # anything else.
        operand_names = set(self.name_to_operand.keys())
        for op in self.operands:
            if op.abbrev is not None:
                if op.abbrev in operand_names:
                    raise ValueError('The name {!r} appears as an operand or '
                                     'abbreviation more than once for '
                                     'instruction {!r}.'
                                     .format(op.abbrev, self.mnemonic))
                operand_names.add(op.abbrev)

        if self.encoding is not None:
            # If we have an encoding, we passed it to the Operand constructors
            # above. This ensured that each operand has a field. However, it's
            # possible that there are some operand names the encoding mentions
            # that don't actually have an operand. Check for that here.
            missing_ops = (set(self.encoding.op_to_field_name.keys()) -
                           set(self.name_to_operand.keys()))
            if missing_ops:
                raise ValueError('Encoding scheme for {} specifies '
                                 'some non-existent operands: {}.'
                                 .format(what, ', '.join(list(missing_ops))))

        self.rv32i = check_bool(yd.get('rv32i', False),
                                'rv32i flag for ' + what)
        self.uses_isr = check_bool(yd.get('uses_isr', False),
                                   'uses_isr flag for ' + what)
        self.glued_ops = check_bool(yd.get('glued-ops', False),
                                    'glued-ops flag for ' + what)
        self.synopsis = get_optional_str(yd, 'synopsis', what)
        self.doc = get_optional_str(yd, 'doc', what)
        self.note = get_optional_str(yd, 'note', what)

        self.errs = None
        if 'errs' in yd:
            errs_what = 'errs field for ' + what
            y_errs = check_list(yd.get('errs'), errs_what)
            self.errs = []
            for idx, err_desc in enumerate(y_errs):
                self.errs.append(check_str(err_desc,
                                           'element {} of the {}'
                                           .format(idx, errs_what)))

        raw_syntax = get_optional_str(yd, 'syntax', what)
        if raw_syntax is not None:
            self.syntax = InsnSyntax.from_yaml(self.mnemonic,
                                               raw_syntax.strip())
        else:
            self.syntax = InsnSyntax.from_list([op.name
                                                for op in self.operands])

        pattern, op_to_grp = self.syntax.asm_pattern()
        self.asm_pattern = re.compile(pattern)
        self.pattern_op_to_grp = op_to_grp

        # Make sure we have exactly the operands we expect.
        if set(self.name_to_operand.keys()) != self.syntax.op_set:
            raise ValueError("Operand syntax for {!r} doesn't have the "
                             "same list of operands as given in the "
                             "operand list. The syntax uses {}, "
                             "but the list of operands gives {}."
                             .format(self.mnemonic,
                                     list(sorted(self.syntax.op_set)),
                                     list(sorted(self.name_to_operand))))

        self.python_pseudo_op = check_bool(yd.get('python-pseudo-op', False),
                                           'python-pseudo-op flag for ' + what)
        if self.python_pseudo_op and self.encoding is not None:
            raise ValueError('{} specifies an encoding and also sets '
                             'python-pseudo-op.'.format(what))

        lpo = yd.get('literal-pseudo-op')
        if lpo is None:
            self.literal_pseudo_op = None
        else:
            lpo_lst = check_list(lpo, 'literal-pseudo-op flag for ' + what)
            for idx, item in enumerate(lpo_lst):
                if not isinstance(item, str):
                    raise ValueError('Item {} of literal-pseudo-op list for '
                                     '{} is {!r}, which is not a string.'
                                     .format(idx, what, item))
            self.literal_pseudo_op = cast(Optional[List[str]], lpo_lst)

            if self.python_pseudo_op:
                raise ValueError('{} specifies both python-pseudo-op and '
                                 'literal-pseudo-op.'
                                 .format(what))
            if self.encoding is not None:
                raise ValueError('{} specifies both an encoding and '
                                 'literal-pseudo-op.'
                                 .format(what))

        lsu_yaml = yd.get('lsu', None)
        if lsu_yaml is None:
            self.lsu = None
        else:
            self.lsu = LSUDesc.from_yaml(lsu_yaml,
                                         'lsu field for {}'.format(what))
            for idx, op_name in enumerate(self.lsu.target):
                if op_name not in self.name_to_operand:
                    raise ValueError('element {} of the target for the lsu '
                                     'field for {} is {!r}, which is not a '
                                     'operand name of the instruction.'
                                     .format(idx, what, op_name))

        self.straight_line = yd.get('straight-line', True)

        iflow_what = 'iflow field for {}'.format(what)
        self.iflow = InsnInformationFlow.from_yaml(yd.get('iflow', None),
                                                   iflow_what, self.operands)

    def enc_vals_to_op_vals(self,
                            cur_pc: int,
                            enc_vals: Dict[str, int]) -> Dict[str, int]:
        '''Convert values extracted from an encoding to their logical values

        This converts between "encoded values" and "operand values" (as defined
        in the OperandType class).

        The enc_vals dictionary should be keyed by the instruction's operand
        names (guaranteed by Encoding.extract_operands). This function should
        only be called when every operand has a width (which will definitely be
        the case if we just decoded these values from an instruction word).

        '''
        op_vals = {}
        for op_name, enc_val in enc_vals.items():
            op_type = self.name_to_operand[op_name].op_type
            op_val = op_type.enc_val_to_op_val(enc_val, cur_pc)
            # This assertion should hold because OperandType.enc_val_to_op_val
            # doesn't return None if the operand type has a width and the
            # function is given a PC.
            assert op_val is not None
            op_vals[op_name] = op_val
        return op_vals

    def disassemble(self,
                    cur_pc: int,
                    op_vals: Dict[str, int]) -> str:
        '''Return disassembly for this instruction

        op_vals should be a dictionary mapping operand names to operand values
        (not encoded values). mnem_width is the width to pad the mnemonic to.

        '''
        hunks = self.syntax.render(cur_pc, op_vals, self.name_to_operand)
        mnem = self.mnemonic
        if hunks and self.glued_ops:
            mnem += hunks[0] + ' '
            hunks = hunks[1:]
        else:
            mnem += ' '

        if len(mnem) < 15:
            mnem += ' ' * (15 - len(mnem))

        # The lstrip here deals with a tricky corner case for instructions like
        # bn.mulqacc if the .z option isn't supplied. In that case, the syntax
        # for the operands starts with a space (following the optional .z that
        # isn't there) and would mess up our alignment.
        return mnem + ''.join(hunks).lstrip()


class DummyInsn(Insn):
    '''A dummy instruction that will never be decoded.

    This shouldn't appear in an InsnGroup or InsnsFile, but can be handy when
    you have an object that wraps an instruction but need to easily handle the
    case of a bogus encoding.

    '''
    def __init__(self) -> None:
        fake_yml = {
            'mnemonic': 'dummy-insn',
            'operands': []
        }
        super().__init__(fake_yml, None, None)


class InsnGroup:
    def __init__(self,
                 path: str,
                 encoding_schemes: Optional[EncSchemes],
                 yml: object,
                 isrs: Optional[IsrMaps]) -> None:

        yd = check_keys(yml, 'insn-group',
                        ['key', 'title', 'doc', 'insns'], [])
        self.key = check_str(yd['key'], 'insn-group key')
        self.title = check_str(yd['title'], 'insn-group title')
        self.doc = check_str(yd['doc'], 'insn-group doc')

        insns_what = 'insns field for {!r} instruction group'.format(self.key)
        insns_rel_path = check_str(yd['insns'], insns_what)
        insns_path = os.path.normpath(os.path.join(os.path.dirname(path),
                                                   insns_rel_path))
        insns_yaml = load_yaml(insns_path, insns_what)
        try:
            self.insns = [Insn(i, encoding_schemes, isrs)
                          for i in check_list(insns_yaml, insns_what)]
        except ValueError as err:
            raise RuntimeError('Invalid schema in YAML file at {!r}: {}'
                               .format(insns_path, err)) from None


class InsnGroups:
    def __init__(self,
                 path: str,
                 encoding_schemes: Optional[EncSchemes],
                 yml: object,
                 isrs: Optional[IsrMaps]) -> None:
        self.groups = [InsnGroup(path, encoding_schemes, y, isrs)
                       for y in check_list(yml, 'insn-groups')]
        if not self.groups:
            raise ValueError('Empty list of instruction groups: '
                             'we need at least one as a base group.')
        self.key_to_group = index_list('insn-groups',
                                       self.groups, lambda ig: ig.key)


class InsnsFile:
    def __init__(self,
                 path: str,
                 yml: object,
                 isrs: Optional[IsrMaps]) -> None:
        yd = check_keys(yml, 'top-level',
                        ['insn-groups'],
                        ['encoding-schemes'])

        enc_scheme_path = get_optional_str(yd, 'encoding-schemes', 'top-level')
        if enc_scheme_path is None:
            self.encoding_schemes = None
        else:
            src_dir = os.path.dirname(path)
            es_path = os.path.normpath(os.path.join(src_dir, enc_scheme_path))
            es_yaml = load_yaml(es_path, 'encoding schemes')
            try:
                self.encoding_schemes = EncSchemes(es_yaml)
            except ValueError as err:
                raise RuntimeError('Invalid schema in YAML file at {!r}: {}'
                                   .format(es_path, err)) from None

        self.groups = InsnGroups(path,
                                 self.encoding_schemes,
                                 yd['insn-groups'],
                                 isrs)

        # The instructions are grouped by instruction group and stored in
        # self.groups. Most of the time, however, we just want "an OTBN
        # instruction" and don't care about the group. Retrieve them here.
        self.insns = []
        for grp in self.groups.groups:
            self.insns += grp.insns

        self.mnemonic_to_insn = index_list('insns', self.insns,
                                           lambda insn: insn.mnemonic.lower())

        masks_exc, ambiguities = self._get_masks()
        # encs = []
        # for m, (z, o) in masks_exc.items():
        #     # print(m, bin(z), bin(o))
        #     enc = ""

        #     for i in range(31, -1, -1):
        #         zi = format(z, '032b')[i]
        #         oi = format(o, '032b')[i]
        #         if zi == "1" and oi == "1":
        #             print("Should not happen")
        #             exit(-1)
        #         if zi == "1":
        #             enc += ("0")
        #         elif oi == "1":
        #             enc += ("1")
        #         else:
        #             enc += (" ")

        #     # print(enc + m.rjust(14))
        #     encs.append(enc + m.rjust(14))
        # encs.sort()
        # for x in encs:
        #     print(x)

        if ambiguities:
            raise ValueError('Ambiguous instruction encodings: ' +
                             ', '.join(ambiguities))

        self._masks = masks_exc

    def grouped_insns(self) -> List[Tuple[InsnGroup, List[Insn]]]:
        '''Return the instructions in groups'''
        return [(grp, grp.insns) for grp in self.groups.groups]

    def _get_masks(self) -> Tuple[Dict[str, Tuple[int, int]], List[str]]:
        '''Generate a list of zeros/ones masks and do ambiguity checks

        Returns a pair (masks, ambiguities). Masks is keyed by instruction
        mnemonic. Its elements are pairs (m0, m1) where m0 is the bits that are
        always zero for this instruction's in the encoding and m1 is the bits
        that are always one. (Bits that can be either are not set in m0 or m1).

        ambiguities is a list of error messages describing ambiguities in the
        encoding. Unless something has gone wrong, it should be empty.

        '''
        masks_inc = {}
        masks_exc = {}
        for insn in self.insns:
            if insn.encoding is not None:
                m0, m1 = insn.encoding.get_masks()
                masks_inc[insn.mnemonic] = (m0, m1)
                masks_exc[insn.mnemonic] = (m0 & ~m1, m1 & ~m0)

        ambiguities = []
        for mnem0, mnem1 in itertools.combinations(masks_inc.keys(), 2):
            m00, m01 = masks_inc[mnem0]
            m10, m11 = masks_inc[mnem1]

            # The pair of instructions is ambiguous if a bit pattern might be
            # either instruction. That happens if each bit index is either
            # allowed to be a 0 in both or allowed to be a 1 in both.
            # ambiguous_mask is the set of bits that don't distinguish the
            # instructions from each other.
            m0 = m00 & m10
            m1 = m01 & m11

            ambiguous_mask = m0 | m1
            if ambiguous_mask == (1 << 32) - 1:
                ambiguities.append('{!r} and {!r} '
                                   'both match bit pattern {:#010x}'
                                   .format(mnem0, mnem1, m1 & ~m0))

        return (masks_exc, ambiguities)

    def mnem_for_word(self, word: int) -> Optional[str]:
        '''Find the instruction that could be encoded as word

        If there is no such instruction, return None.

        '''
        ret = None
        for mnem, (m0, m1) in self._masks.items():
            # If any bit is set that should be zero or if any bit is clear that
            # should be one, ignore this instruction.
            if word & m0 or (~ word) & m1:
                continue

            # Belt-and-braces ambiguity check
            assert ret is None
            ret = mnem

        return ret


def load_file(path: str, isrs: Optional[IsrMaps]) -> InsnsFile:
    '''Load the YAML file at path.

    Raises a RuntimeError on syntax or schema error.

    '''
    try:
        return InsnsFile(path, load_yaml(path, None), isrs)
    except ValueError as err:
        raise RuntimeError('Invalid schema in YAML file at {!r}: {}'
                           .format(path, err)) from None


def make_isr_dict(path: str) -> IsrMap:
    '''Load a YAML file at path and return a map from name to Isr.'''
    try:
        name_to_isr = {}  # type: Dict[str, Isr]
        for isr in read_isrs(path):
            name = isr.name.lower()
            if name in name_to_isr:
                raise ValueError(f'Duplicate ISRs with name {name}.')
            name_to_isr[name] = isr
        return IsrMap(name_to_isr)

    except ValueError as err:
        raise RuntimeError('Invalid schema in ISR YAML file at {!r}: {}'
                           .format(path, err)) from None


_DEFAULT_INSNS_FILE = None  # type: Optional[InsnsFile]


def load_insns_yaml() -> InsnsFile:
    '''Load the insns.yml file from its default location.

    Caches its result. Raises a RuntimeError on syntax or schema error.

    '''
    global _DEFAULT_INSNS_FILE
    if _DEFAULT_INSNS_FILE is not None:
        return _DEFAULT_INSNS_FILE

    dirname = os.path.dirname(__file__)
    data_path = os.path.normpath(os.path.join(dirname, '..', '..', 'data'))

    csrs = make_isr_dict(os.path.join(data_path, 'csr.yml'))
    wsrs = make_isr_dict(os.path.join(data_path, 'wsr.yml'))

    _DEFAULT_INSNS_FILE = load_file(os.path.join(data_path, 'insns.yml'),
                                    IsrMaps(csrs, wsrs))

    return _DEFAULT_INSNS_FILE
