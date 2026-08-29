from __future__ import annotations

import os
import stat
import tempfile
from dataclasses import dataclass
from pathlib import Path

from eth_account import Account


@dataclass(frozen=True, slots=True)
class AgentWallet:
    address: str
    private_key: str
    path: Path


def default_agent_path() -> Path:
    override = os.environ.get("PANDA_POPDEX_AGENT_ENV")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".config" / "pandazhai" / "popdex-agent" / "agent.env"


def private_permissions(path: Path) -> bool:
    return os.name == "nt" or stat.S_IMODE(path.stat().st_mode) & 0o077 == 0


def load_agent(path: Path) -> AgentWallet:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        key, separator, value = raw.partition("=")
        if separator:
            values[key.strip()] = value.strip()
    address = values.get("POPDEX_AGENT_ADDRESS", "")
    private_key = values.get("POPDEX_SIGNER_PRIVATE_KEY", "")
    if not address or not private_key:
        raise ValueError(f"Agent 文件缺少地址或私钥：{path}")
    derived = Account.from_key(private_key).address
    if derived.lower() != address.lower():
        raise ValueError(f"Agent 地址与私钥不匹配：{path}")
    if not private_permissions(path):
        raise PermissionError(f"Agent 文件权限过宽，请执行：chmod 600 {path}")
    return AgentWallet(address=address, private_key=private_key, path=path)


def create_agent(path: Path) -> AgentWallet:
    target = path.expanduser().resolve()
    if target.exists():
        return load_agent(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if os.name != "nt":
        target.parent.chmod(0o700)
    account = Account.create()
    private_key = account.key.hex()
    if not private_key.startswith("0x"):
        private_key = "0x" + private_key
    content = (
        f"POPDEX_AGENT_ADDRESS={account.address}\n"
        f"POPDEX_SIGNER_PRIVATE_KEY={private_key}\n"
    )
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".agent-", suffix=".tmp", dir=target.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        if os.name != "nt":
            temporary.chmod(0o600)
        temporary.replace(target)
        if os.name != "nt":
            target.chmod(0o600)
    finally:
        temporary.unlink(missing_ok=True)
    return AgentWallet(address=account.address, private_key=private_key, path=target)
