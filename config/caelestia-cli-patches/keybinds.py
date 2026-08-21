import subprocess
from argparse import Namespace


class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        cmd = ["caelestia-keybinds"]
        if self.args.filter:
            cmd.append(self.args.filter)
        subprocess.run(cmd)
