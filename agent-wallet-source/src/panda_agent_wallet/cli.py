from __future__ import annotations

import argparse
import getpass
import os
import sys
from pathlib import Path

import httpx
from eth_account import Account
from web3 import Web3

from panda_agent_wallet.wallet import create_agent, default_agent_path


POPDEX_RPC = "https://api.popdex.xyz/api/v1/web3/rpc"
POPDEX_TIME_URL = "https://api.popdex.xyz/api/v1/public/time"
POPDEX_CHAIN_ID = 2184
ACCOUNT_CONTRACT = "0x0000000000000000000000000000000000001008"
ACCOUNT_ABI = [
    {
        "type": "function",
        "name": "approveAgent",
        "stateMutability": "nonpayable",
        "inputs": [
            {"name": "agent", "type": "address"},
            {"name": "delegator", "type": "address"},
            {"name": "name", "type": "bytes32"},
            {"name": "expiresAt", "type": "uint64"},
            {"name": "initialNonce", "type": "uint64"},
            {"name": "isGlobal", "type": "bool"},
        ],
        "outputs": [],
    },
    {
        "type": "function",
        "name": "getAgentInfo",
        "stateMutability": "view",
        "inputs": [{"name": "agent", "type": "address"}],
        "outputs": [
            {"name": "exists", "type": "bool"},
            {"name": "expiresAt", "type": "uint64"},
            {"name": "isExpired", "type": "bool"},
            {"name": "delegator", "type": "address"},
            {"name": "name", "type": "bytes32"},
            {"name": "isGlobal", "type": "bool"},
            {"name": "agentType", "type": "uint8"},
            {"name": "scope", "type": "uint8"},
            {"name": "allowedRecipients", "type": "address[]"},
        ],
    },
]


def terminal_input(prompt: str, *, hidden: bool = False) -> str:
    if hidden:
        return getpass.getpass(prompt).strip()
    if sys.stdin.isatty() or os.name == "nt":
        return input(prompt).strip()
    print(prompt, end="", flush=True)
    with open("/dev/tty", "r", encoding="utf-8") as terminal:
        return terminal.readline().strip()


def encode_name(name: str) -> bytes:
    encoded = name.encode("utf-8")
    if not encoded or len(encoded) > 32:
        raise ValueError("Agent 名称的 UTF-8 长度必须为 1 到 32 字节")
    return encoded.ljust(32, b"\0")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="在本机创建并授权 POPDEX Agent 钱包")
    parser.add_argument("--agent-env", type=Path, default=default_agent_path())
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--name")
    parser.add_argument("--rpc-url", default=POPDEX_RPC)
    parser.add_argument("--create-only", action="store_true", help="只创建 Agent，不进行授权")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)
    if args.days <= 0:
        raise SystemExit("--days 必须大于 0")
    print("熊猫寨 POPDEX Agent 钱包工具 v0.2.0")
    print("主钱包私钥仅在本机内存中用于签名，不保存、不上传、不写日志。")
    main_private_key = terminal_input("\n请输入 POPDEX 主钱包私钥（输入不会显示）：", hidden=True)
    try:
        signer = Account.from_key(main_private_key)
    except Exception as exc:
        raise SystemExit("主钱包私钥格式无效") from exc
    finally:
        main_private_key = ""

    agent = create_agent(args.agent_env)
    print("\n请立即离线备份以下 Agent 信息：")
    print("  主钱包地址   :", signer.address)
    print("  Agent 地址  :", agent.address)
    print("  Agent 私钥  :", agent.private_key)
    print("  本地备份文件 :", agent.path)
    print("  文件权限     : 0600（仅当前用户可读）")

    if args.create_only:
        print("\n已按 --create-only 结束，未发送授权交易。")
        return

    try:
        time_response = httpx.get(POPDEX_TIME_URL, timeout=15)
        time_response.raise_for_status()
        timestamp = int(time_response.json()["data"]["systemTs"])
        web3 = Web3(Web3.HTTPProvider(args.rpc_url, request_kwargs={"timeout": 15}))
        if not web3.is_connected():
            raise RuntimeError("无法连接 POPDEX RPC")
        if web3.eth.chain_id != POPDEX_CHAIN_ID:
            raise RuntimeError(f"链 ID 错误：期望 {POPDEX_CHAIN_ID}，实际 {web3.eth.chain_id}")
        name = args.name or f"panda-{agent.address[-8:].lower()}"
        contract = web3.eth.contract(
            address=Web3.to_checksum_address(ACCOUNT_CONTRACT), abi=ACCOUNT_ABI
        )
        approval = contract.functions.approveAgent(
            Web3.to_checksum_address(agent.address),
            Web3.to_checksum_address(signer.address),
            encode_name(name),
            timestamp + args.days * 86_400_000,
            timestamp,
            False,
        )
        estimated_gas = approval.estimate_gas({"from": signer.address})
    except Exception as exc:
        raise SystemExit(f"\n授权预演失败，未发送交易：{exc}") from exc

    print("\n授权预演通过：")
    print("  网络/Chain ID : POPDEX /", POPDEX_CHAIN_ID)
    print("  授权有效期     :", args.days, "天")
    print("  Agent 名称     :", name)
    print("  Gas 估算       :", estimated_gas)
    confirmation = terminal_input("\n输入大写 AUTHORIZE 发送授权交易，直接回车则取消：")
    if confirmation != "AUTHORIZE":
        print("已取消授权，Agent 文件仍保存在本机。")
        return

    latest_block = web3.eth.get_block("latest")
    base_fee = latest_block.get("baseFeePerGas") or Web3.to_wei(1, "gwei")
    transaction = approval.build_transaction(
        {
            "from": signer.address,
            "chainId": POPDEX_CHAIN_ID,
            "nonce": web3.eth.get_transaction_count(signer.address, "pending"),
            "gas": int(estimated_gas * 1.2),
            "type": 2,
            "maxFeePerGas": int(base_fee * 2),
            "maxPriorityFeePerGas": 0,
            "value": 0,
        }
    )
    signed = signer.sign_transaction(transaction)
    tx_hash = web3.eth.send_raw_transaction(signed.raw_transaction)
    print("交易已发送：", tx_hash.hex())
    receipt = web3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)
    if receipt.status != 1:
        raise SystemExit("授权交易执行失败：" + tx_hash.hex())
    info = contract.functions.getAgentInfo(agent.address).call()
    if not info[0] or info[2]:
        raise SystemExit("交易已确认，但 Agent 状态验证失败")
    print("授权成功，区块：", receipt.blockNumber)
    print("Agent 私钥：", agent.private_key)


if __name__ == "__main__":
    main()
