import useWallet from "./hooks/useWallet";


export default function App() {

  const wallet =
    useWallet();


  return (

    <div
      style={{
        padding: "40px",
        fontFamily: "Arial"
      }}
    >

      <h1>
        Aralys Finance 
      </h1>

      <hr />


      <h2>
        Wallet
      </h2>


      <button
        onClick={
          wallet.connect
        }
      >
        Connect Wallet
      </button>


      <p>
        {wallet.account}
      </p>


      <p>
        {wallet.balance} ETH
      </p>


      <p>
        {wallet.arlyBalance} ARLY
      </p>


      <hr />


      <h2>
        Swap
      </h2>


      <input
        placeholder="Amount"
      />


      <button>
        Swap
      </button>


      <hr />


      <h2>
        Vault
      </h2>


      <button>
        Deposit
      </button>


      <button>
        Withdraw
      </button>


      <hr />


      <h2>
        Lending
      </h2>


      <button>
        Borrow
      </button>


      <button>
        Repay
      </button>


      <hr />


      <h2>
        DAO
      </h2>


      <button>
        Create Proposal
      </button>


      <button>
        Vote
      </button>

    </div>

  );

}