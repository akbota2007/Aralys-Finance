import { useState } from "react";

import {
  BrowserProvider,
  Contract
}
from "ethers";

import ARLYAbi
from "../abi/ARLY.json";

import {
  CONTRACTS
}
from "../config";


export default function useWallet() {

  const [account, setAccount] =
    useState("");

  const [balance, setBalance] =
    useState("");

  const [arlyBalance, setArlyBalance] =
    useState("0");


  async function connect() {

    if (!window.ethereum) {
      alert("Install MetaMask");
      return;
    }


    const provider =
      new BrowserProvider(
        window.ethereum
      );


    const accounts =
      await provider.send(
        "eth_requestAccounts",
        []
      );


    const walletBalance =
      await provider.getBalance(
        accounts[0]
      );


    setAccount(
      accounts[0]
    );


    setBalance(
      (
        Number(walletBalance) /
        1e18
      ).toFixed(4)
    );


    try {

      const token =
        new Contract(
          CONTRACTS.ARLY,
          ARLYAbi.abi,
          provider
        );


      const rawBalance =
        await token.balanceOf(
          accounts[0]
        );


      setArlyBalance(
        (
          Number(rawBalance) /
          1e18
        ).toFixed(2)
      );

    }

    catch (error) {

      console.log(
        error
      );

    }

  }


  return {

    account,

    balance,

    arlyBalance,

    connect

  };

}