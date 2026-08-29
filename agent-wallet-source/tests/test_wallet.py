from pathlib import Path

from eth_account import Account

from panda_agent_wallet.cli import encode_name
from panda_agent_wallet.wallet import create_agent, load_agent, private_permissions


def test_create_and_reuse_agent(tmp_path: Path) -> None:
    target = tmp_path / "private" / "agent.env"
    first = create_agent(target)
    second = create_agent(target)
    assert first.address == second.address
    assert first.private_key == second.private_key
    assert Account.from_key(first.private_key).address == first.address
    assert load_agent(target).address == first.address
    assert private_permissions(target)


def test_encode_name() -> None:
    assert encode_name("panda").startswith(b"panda")
    assert len(encode_name("panda")) == 32
