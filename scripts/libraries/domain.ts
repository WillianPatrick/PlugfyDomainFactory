/* global ethers */
import { Contract } from "ethers";

export function getSelectors (contract: Contract): string[] {
  const signatures = Object.keys(contract.interface.functions)
  const selectors = signatures.reduce((acc: string[], val: string) => {
      acc.push(contract.interface.getSighash(val))
    return acc
  }, []);
  return selectors
}

export function getFunctionSignature(contract: Contract, functionName: string): string | null {
  const contractFunctions = contract.interface.functions;
  if (!contractFunctions[functionName]) {
      return null;
  }
  return contract.interface.getSighash(functionName);
}

function getAppAddressesBySelectors(contract: Contract, functionNames: string[]): string[] {
  const addresses = functionNames.map(functionName => {
      const sighash = contract.interface.getSighash(functionName);
      return contract.functions[sighash]?.address?.toHexString() ?? null;
  }).filter(address => address !== null);
  
  return addresses;
}