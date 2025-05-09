// SPDX-License-Identifier: BUSL-1.1
// NatSpec format convention - https://docs.soliditylang.org/en/v0.5.10/natspec-format.html
pragma solidity 0.8.26;

// se podria aprovechar la logica de los modifier para establecer control de ejecucion antes y despues
// crear un onCall modifier para agregar a los metodo y registrar en base a cada hook acciones especificas en el llamado

// pre - validate
// during - execute
// pos - verify
