#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
AXI Crossbar Top Level Generator - TUI Interface
Uses Textual and Rich for a terminal-based UI

Generated config is compatible with template_top_level.py structure
"""

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Import after ensuring venv
SCRIPTDIR = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))
sys.path.insert(0, SCRIPTDIR)

try:
    from textual.app import App, ComposeResult
    from textual.containers import Container, Grid, ScrollableContainer
    from textual.widgets import (
        Button, Footer, Header, Input, Label, ListItem, ListView,
        RadioButton, RadioSet, Select, Static, Switch
    )
    from textual.screen import Screen
    from textual.events import Mount
    from rich.text import Text
    from rich.panel import Panel
    from rich.table import Table
    from rich import box
    TEXTUAL_IMPORTED = True
except ImportError as e:
    TEXTUAL_IMPORTED = False
    print(f"Error importing Textual/Rich: {e}")
    print("Please install with: pip install textual rich")
    sys.exit(1)


# ============================================================================
# Configuration Data Model (compatible with template_top_level.py)
# ============================================================================

class AXIConfig:
    """Main configuration class matching template_top_level.py structure"""

    def __init__(self):
        self.global_config = {
            "AXI_ADDR_W": 8,
            "AXI_ID_W": 8,
            "AXI_DATA_W": 8,
            "MST_NB": 2,
            "SLV_NB": 2,
            "OR_NUM_W": 8,
            "MST_PIPELINE": 0,
            "SLV_PIPELINE": 0,
            "USER_SUPPORT": 0,
            "AXI_AUSER_W": 1,
            "AXI_WUSER_W": 1,
            "AXI_BUSER_W": 1,
            "AXI_RUSER_W": 1,
            "TIMEOUT_VALUE": 10000,
            "TIMEOUT_ENABLE": 1,
            "NUM_PRIORITY_LVL": 4,
            "AXI_SIGNALING": 1,  # Will be set to 0 for axi4lite
        }
        self.masters: List[Dict] = []
        self.slaves: List[Dict] = []
        self.axi_type = "axi4"

    def to_template_dict(self) -> Dict:
        """Convert to dictionary format expected by template_top_level.py"""
        return {
            "global": self.global_config,
            "masters": self.masters,
            "slaves": self.slaves,
        }

    def save(self, filepath: str):
        """Save configuration to JSON file"""
        data = {
            "global": self.global_config,
            "masters": self.masters,
            "slaves": self.slaves,
            "axi_type": self.axi_type,
        }
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)

    def add_master(self):
        """Add a new master with default values"""
        idx = len(self.masters)
        self.masters.append({
            "CDC": 0,
            "OSTDREQ_NUM": 4,
            "PRIORITY": 0,
            "ROUTES": f"{self.global_config.get('SLV_NB', 2)}'b{'_'.join(['1'] * self.global_config.get('SLV_NB', 2))}",
            "ID_MASK": 0x10 * (idx + 1),
            "RW": 0,
        })
        if self.axi_type == "axi4":
            self.masters[-1]["OSTDREQ_SIZE"] = 1
        self.global_config["MST_NB"] = len(self.masters)

    def remove_master(self, index: int):
        """Remove a master by index"""
        if 0 <= index < len(self.masters):
            self.masters.pop(index)
            self.global_config["MST_NB"] = len(self.masters)

    def add_slave(self):
        """Add a new slave with default values"""
        slv_nb = self.global_config.get("SLV_NB", 2)
        addr_w = self.global_config.get("AXI_ADDR_W", 8)

        # Calculate address ranges
        addr_size = 2 ** addr_w
        slave_addr_size = addr_size // slv_nb if slv_nb > 0 else addr_size

        idx = len(self.slaves)
        if addr_w == 8:
            # Use fixed ranges for 8-bit address
            ranges = [
                (0, 4095), (4096, 8191), (8192, 12287), (12288, 16383)
            ]
            start, end = ranges[idx] if idx < len(ranges) else (idx * slave_addr_size, (idx + 1) * slave_addr_size - 1)
        else:
            start = idx * slave_addr_size
            end = ((idx + 1) * slave_addr_size) - 1

        self.slaves.append({
            "CDC": 0,
            "START_ADDR": start,
            "END_ADDR": end,
            "OSTDREQ_NUM": 4,
            "KEEP_BASE_ADDR": 0,
        })
        if self.axi_type == "axi4":
            self.slaves[-1]["OSTDREQ_SIZE"] = 1
        self.global_config["SLV_NB"] = len(self.slaves)

    def remove_slave(self, index: int):
        """Remove a slave by index"""
        if 0 <= index < len(self.slaves):
            self.slaves.pop(index)
            self.global_config["SLV_NB"] = len(self.slaves)


# Global config instance
config = AXIConfig()


# ============================================================================
# Custom Widgets
# ============================================================================

class MasterCard(ScrollableContainer):
    """Card widget to display and edit a single master configuration"""

    def __init__(self, master_data: Dict, master_index: int, **kwargs):
        super().__init__(**kwargs)
        self.master_data = master_data.copy()
        self.master_index = master_index
        # Use unique dynamic ID to avoid conflicts
        import uuid
        self.id = f"master-{master_index}-{uuid.uuid4().hex[:8]}"

    def compose(self) -> ComposeResult:
        with Container(id=f"master-container-{self.master_index}", classes="card"):
            yield Label(f"[bold]Master {self.master_index}[/bold]", id=f"master-title-{self.master_index}")
            yield Label("CDC")
            yield Switch(value=bool(self.master_data.get("CDC", 0)), id=f"master-cdc-{self.master_index}")
            yield Label("Outstanding Req Num")
            yield Input(value=str(self.master_data.get("OSTDREQ_NUM", 4)), id=f"master-ostdreq-num-{self.master_index}")
            if "OSTDREQ_SIZE" in self.master_data:
                yield Label("Outstanding Req Size")
                yield Input(value=str(self.master_data.get("OSTDREQ_SIZE", 1)), id=f"master-ostdreq-size-{self.master_index}")
            yield Label("Priority")
            yield Input(value=str(self.master_data.get("PRIORITY", 0)), id=f"master-priority-{self.master_index}")
            yield Label("Routes")
            yield Input(value=self.master_data.get("ROUTES", ""), id=f"master-routes-{self.master_index}")
            yield Label("ID Mask")
            yield Input(value=hex(self.master_data.get("ID_MASK", 0)), id=f"master-idmask-{self.master_index}")


class SlaveCard(ScrollableContainer):
    """Card widget to display and edit a single slave configuration"""

    def __init__(self, slave_data: Dict, slave_index: int, **kwargs):
        super().__init__(**kwargs)
        self.slave_data = slave_data.copy()
        self.slave_index = slave_index
        # Use unique dynamic ID to avoid conflicts
        import uuid
        self.id = f"slave-{slave_index}-{uuid.uuid4().hex[:8]}"

    def compose(self) -> ComposeResult:
        with Container(id=f"slave-container-{self.slave_index}", classes="card"):
            yield Label(f"[bold]Slave {self.slave_index}[/bold]", id=f"slave-title-{self.slave_index}")
            yield Label("CDC")
            yield Switch(value=bool(self.slave_data.get("CDC", 0)), id=f"slave-cdc-{self.slave_index}")
            yield Label("Start Address")
            yield Input(value=str(self.slave_data.get("START_ADDR", 0)), id=f"slave-start-{self.slave_index}")
            yield Label("End Address")
            yield Input(value=str(self.slave_data.get("END_ADDR", 0)), id=f"slave-end-{self.slave_index}")
            yield Label("Outstanding Req Num")
            yield Input(value=str(self.slave_data.get("OSTDREQ_NUM", 4)), id=f"slave-ostdreq-num-{self.slave_index}")
            if "OSTDREQ_SIZE" in self.slave_data:
                yield Label("Outstanding Req Size")
                yield Input(value=str(self.slave_data.get("OSTDREQ_SIZE", 1)), id=f"slave-ostdreq-size-{self.slave_index}")
            yield Label("Keep Base Addr")
            yield Switch(value=bool(self.slave_data.get("KEEP_BASE_ADDR", 0)), id=f"slave-keep-{self.slave_index}")


# ============================================================================
# Screens
# ============================================================================


class GlobalSettingsScreen(Screen):
    """Screen for global configuration"""

    def compose(self) -> ComposeResult:
        yield Header()
        with ScrollableContainer(id="global-scroll"):
            yield Label("[bold]Global Settings[/bold]", id="global-title")
            yield Label("")

            # AXI Interface
            yield Label("[bold]AXI Protocol[/bold]")
            yield Label("Apply to the whole fabric")
            with RadioSet(id="protocol-select"):
                yield RadioButton("AXI4", value="axi4", id="radio-axi4")
                yield RadioButton("AXI4-lite", value="axi4lite", id="radio-axi4lite" )

            # Address/ID/Data Width
            yield Label("[bold]Bus Widths[/bold]")
            yield Label("Address Width (bits)")
            yield Input(value=str(config.global_config.get("AXI_ADDR_W", 8)), id="addr-w")
            yield Label("ID Width (bits)")
            yield Input(value=str(config.global_config.get("AXI_ID_W", 8)), id="id-w")
            yield Label("Data Width (bits)")
            yield Input(value=str(config.global_config.get("AXI_DATA_W", 8)), id="data-w")
            yield Label("")

            # Master/Slave Count
            yield Label("[bold]Master/Slave Configuration[/bold]")
            yield Label("Number of Masters")
            yield Input(value=str(config.global_config.get("MST_NB", 2)), id="mst-nb")
            yield Label("Number of Slaves")
            yield Input(value=str(config.global_config.get("SLV_NB", 2)), id="slv-nb")
            yield Label("")

            # Pipelining
            yield Label("[bold]Pipelining[/bold]")
            yield Label("Master Pipeline")
            yield Switch(value=bool(config.global_config.get("MST_PIPELINE", 0)), id="mst-pipeline")
            yield Label("Slave Pipeline")
            yield Switch(value=bool(config.global_config.get("SLV_PIPELINE", 0)), id="slv-pipeline")
            yield Label("")

            # User Support
            yield Label("[bold]User Fields[/bold]")
            yield Label("Enable USER Support")
            yield Switch(value=bool(config.global_config.get("USER_SUPPORT", 0)), id="user-support")
            yield Label("AUSER Width")
            yield Input(value=str(config.global_config.get("AXI_AUSER_W", 1)), id="auser-w")
            yield Label("WUSER Width")
            yield Input(value=str(config.global_config.get("AXI_WUSER_W", 1)), id="wuser-w")
            yield Label("BUSER Width")
            yield Input(value=str(config.global_config.get("AXI_BUSER_W", 1)), id="buser-w")
            yield Label("RUSER Width")
            yield Input(value=str(config.global_config.get("AXI_RUSER_W", 1)), id="ruser-w")
            yield Label("")

            # Timeout
            # yield Label("[bold]Timeout Settings[/bold]")
            # yield Label("Timeout Value")
            # yield Input(value=str(config.global_config.get("TIMEOUT_VALUE", 10000)), id="timeout-value")
            # yield Label("Enable Timeout")
            # yield Switch(value=bool(config.global_config.get("TIMEOUT_ENABLE", 1)), id="timeout-enable")
            yield Label("Priority Levels")
            yield Input(value=str(config.global_config.get("NUM_PRIORITY_LVL", 4)), id="priority-lvl")
            yield Label("")

            # Navigation
            yield Button("Next: Masters", id="next-masters", variant="primary")

        yield Footer()


    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "next-masters":
            self._save_values()
            # Update master/slave counts
            config.global_config["MST_NB"] = int(self.query_one("#mst-nb", Input).value or "2")
            config.global_config["SLV_NB"] = int(self.query_one("#slv-nb", Input).value or "2")
            # Initialize masters/slaves if empty
            while len(config.masters) < config.global_config["MST_NB"]:
                config.add_master()
            while len(config.masters) > config.global_config["MST_NB"]:
                config.remove_master(len(config.masters) - 1)
            while len(config.slaves) < config.global_config["SLV_NB"]:
                config.add_slave()
            while len(config.slaves) > config.global_config["SLV_NB"]:
                config.remove_slave(len(config.slaves) - 1)
            self.app.switch_screen("masters")

    def on_radio_set_changed(self, event: RadioSet.Changed) -> None:
        protocol = str(event.pressed.label)
        if (protocol == "AXI4-lite"):
            config.global_config["AXI_SIGNALING"] = "0"
            config.axi_type = "axi4lite"
        else:
            config.global_config["AXI_SIGNALING"] = "1"
            config.axi_type = "axi4"

    def _save_values(self):
        """Save all input values to config"""
        config.global_config["AXI_ADDR_W"] = int(self.query_one("#addr-w", Input).value or "8")
        config.global_config["AXI_ID_W"] = int(self.query_one("#id-w", Input).value or "8")
        config.global_config["AXI_DATA_W"] = int(self.query_one("#data-w", Input).value or "8")
        config.global_config["MST_PIPELINE"] = int(self.query_one("#mst-pipeline", Switch).value)
        config.global_config["SLV_PIPELINE"] = int(self.query_one("#slv-pipeline", Switch).value)
        config.global_config["USER_SUPPORT"] = int(self.query_one("#user-support", Switch).value)
        config.global_config["AXI_AUSER_W"] = int(self.query_one("#auser-w", Input).value or "1")
        config.global_config["AXI_WUSER_W"] = int(self.query_one("#wuser-w", Input).value or "1")
        config.global_config["AXI_BUSER_W"] = int(self.query_one("#buser-w", Input).value or "1")
        config.global_config["AXI_RUSER_W"] = int(self.query_one("#ruser-w", Input).value or "1")
        # config.global_config["TIMEOUT_VALUE"] = int(self.query_one("#timeout-value", Input).value or "10000")
        # config.global_config["TIMEOUT_ENABLE"] = int(self.query_one("#timeout-enable", Switch).value)
        config.global_config["NUM_PRIORITY_LVL"] = int(self.query_one("#priority-lvl", Input).value or "4")


class MastersScreen(Screen):
    """Screen for master configuration"""

    def compose(self) -> ComposeResult:
        yield Header()
        with ScrollableContainer(id="masters-scroll"):
            yield Label(f"[bold]Master Configuration ({config.global_config.get('MST_NB', 0)} masters)[/bold]", id="masters-title")
            yield Label("[dim]Configure each master interface[/dim]")
            yield Label("")

            # Master cards
            masters_container = Container(id="masters-list")
            yield masters_container

            # Add/Remove buttons
            with Container(id="master-actions"):
                yield Button("[+] Add Master", id="add-master")
                yield Button("[-] Remove Last", id="remove-master")
            yield Label("")

            # Navigation
            yield Button("Back", id="back-btn")
            yield Button("Next: Slaves", id="next-slaves", variant="primary")
        yield Footer()

    def on_mount(self, event: Mount) -> None:
        self._refresh_masters()

    def _refresh_masters(self):
        """Refresh the master cards display"""
        masters_container = self.query_one("#masters-list", Container)
        masters_container.remove_children()
        for i, master in enumerate(config.masters):
            masters_container.mount(MasterCard(master, i))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back-btn":
            self.app.switch_screen("global")
        elif event.button.id == "add-master":
            config.add_master()
            self._refresh_masters()
        elif event.button.id == "remove-master":
            if len(config.masters) > 0:
                config.remove_master(len(config.masters) - 1)
                self._refresh_masters()
        elif event.button.id == "next-slaves":
            self._save_master_values()
            # Update slave routes based on master count
            for master in config.masters:
                slv_nb = config.global_config.get("SLV_NB", 2)
                master["ROUTES"] = f"{slv_nb}'b{'_'.join(['1'] * slv_nb)}"
            self.app.switch_screen("slaves")

    def _save_master_values(self):
        """Save all master values from the form"""
        for i in range(len(config.masters)):
            if i < len(config.masters):
                config.masters[i]["CDC"] = int(self.query_one(f"#master-cdc-{i}", Switch).value)
                config.masters[i]["OSTDREQ_NUM"] = int(self.query_one(f"#master-ostdreq-num-{i}", Input).value or "4")
                config.masters[i]["PRIORITY"] = int(self.query_one(f"#master-priority-{i}", Input).value or "0")
                config.masters[i]["ROUTES"] = self.query_one(f"#master-routes-{i}", Input).value or ""
                try:
                    config.masters[i]["ID_MASK"] = int(self.query_one(f"#master-idmask-{i}", Input).value or "0", 16)
                except ValueError:
                    config.masters[i]["ID_MASK"] = 0
                if config.axi_type == "axi4":
                    config.masters[i]["OSTDREQ_SIZE"] = int(self.query_one(f"#master-ostdreq-size-{i}", Input).value or "1")


class SlavesScreen(Screen):
    """Screen for slave configuration"""

    def compose(self) -> ComposeResult:
        yield Header()
        with ScrollableContainer(id="slaves-scroll"):
            yield Label(f"[bold]Slave Configuration ({config.global_config.get('SLV_NB', 0)} slaves)[/bold]", id="slaves-title")
            yield Label("[dim]Configure each slave interface[/dim]")
            yield Label("")

            # Slave cards
            slaves_container = Container(id="slaves-list")
            yield slaves_container

            # Add/Remove buttons
            with Container(id="slave-actions"):
                yield Button("[+] Add Slave", id="add-slave")
                yield Button("[-] Remove Last", id="remove-slave")
            yield Label("")

            # Navigation
            yield Button("Back", id="back-btn")
            yield Button("Next: Generate", id="next-generate", variant="primary")
        yield Footer()

    def on_mount(self, event: Mount) -> None:
        self._refresh_slaves()

    def _refresh_slaves(self):
        """Refresh the slave cards display"""
        slaves_container = self.query_one("#slaves-list", Container)
        slaves_container.remove_children()
        for i, slave in enumerate(config.slaves):
            slaves_container.mount(SlaveCard(slave, i))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back-btn":
            self.app.switch_screen("masters")
        elif event.button.id == "add-slave":
            config.add_slave()
            self._refresh_slaves()
        elif event.button.id == "remove-slave":
            if len(config.slaves) > 0:
                config.remove_slave(len(config.slaves) - 1)
                self._refresh_slaves()
        elif event.button.id == "next-generate":
            self._save_slave_values()
            self.app.switch_screen("generate")

    def _save_slave_values(self):
        """Save all slave values from the form"""
        for i in range(len(config.slaves)):
            if i < len(config.slaves):
                config.slaves[i]["CDC"] = int(self.query_one(f"#slave-cdc-{i}", Switch).value)
                try:
                    config.slaves[i]["START_ADDR"] = int(self.query_one(f"#slave-start-{i}", Input).value or "0")
                except ValueError:
                    config.slaves[i]["START_ADDR"] = 0
                try:
                    config.slaves[i]["END_ADDR"] = int(self.query_one(f"#slave-end-{i}", Input).value or "0")
                except ValueError:
                    config.slaves[i]["END_ADDR"] = 0
                config.slaves[i]["OSTDREQ_NUM"] = int(self.query_one(f"#slave-ostdreq-num-{i}", Input).value or "4")
                config.slaves[i]["KEEP_BASE_ADDR"] = int(self.query_one(f"#slave-keep-{i}", Switch).value)
                if config.axi_type == "axi4":
                    config.slaves[i]["OSTDREQ_SIZE"] = int(self.query_one(f"#slave-ostdreq-size-{i}", Input).value or "1")


class GenerateScreen(Screen):
    """Screen for preview and generation"""

    def compose(self) -> ComposeResult:
        yield Header()
        with ScrollableContainer(id="generate-scroll"):
            yield Label("[bold]Configuration Preview[/bold]", id="preview-title")
            yield Label("")

            # Display config summary
            preview = Static(id="preview-content")
            yield preview

            yield Label("")

            # Actions
            with Container(id="generate-actions"):
                yield Button("Back", id="back-btn")
                yield Button("[bold]Generate[/bold]", id="generate-btn", variant="success")

            yield Static(id="status")
        yield Footer()

    def on_mount(self, event: Mount) -> None:
        self._update_preview()

    def _update_preview(self):
        """Update the preview content"""
        preview = self.query_one("#preview-content", Static)

        # Build preview table
        table = Table(title="Configuration Summary", box=box.ROUNDED, show_header=True)
        table.add_column("Parameter", style="cyan")
        table.add_column("Value", style="green")

        # Global config
        table.add_row("[bold]Global[/bold]", "")
        table.add_row("AXI Type", config.axi_type.upper())
        table.add_row("Address Width", f"{config.global_config.get('AXI_ADDR_W', 8)} bits")
        table.add_row("ID Width", f"{config.global_config.get('AXI_ID_W', 8)} bits")
        table.add_row("Data Width", f"{config.global_config.get('AXI_DATA_W', 8)} bits")
        table.add_row("Masters", str(config.global_config.get('MST_NB', 0)))
        table.add_row("Slaves", str(config.global_config.get('SLV_NB', 0)))
        table.add_row("Pipelining", f"MST:{config.global_config.get('MST_PIPELINE', 0)}, SLV:{config.global_config.get('SLV_PIPELINE', 0)}")
        table.add_row("User Support", "Enabled" if config.global_config.get('USER_SUPPORT', 0) else "Disabled")

        # Masters
        table.add_row("", "")
        table.add_row("[bold]Masters[/bold]", "")
        for i, master in enumerate(config.masters):
            table.add_row(f"Master {i}", f"CDC:{master.get('CDC', 0)}, Priority:{master.get('PRIORITY', 0)}, Routes:{master.get('ROUTES', 'N/A')}")

        # Slaves
        table.add_row("", "")
        table.add_row("[bold]Slaves[/bold]", "")
        for i, slave in enumerate(config.slaves):
            table.add_row(f"Slave {i}", f"Addr:0x{slave.get('START_ADDR', 0):X}-0x{slave.get('END_ADDR', 0):X}, CDC:{slave.get('CDC', 0)}")

        preview.update(Panel(table, title="[bold]Configuration[/bold]", border_style="blue"))

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back-btn":
            self.app.switch_screen("slaves")
        elif event.button.id == "generate-btn":
            self._generate_output()

    def _generate_output(self):
        """Generate the output file using template_top_level.py"""

        config.save(config.global_config["OUTPUT_FILE"])


class AXICrossbarTUI(App):
    """Main TUI Application for AXI Crossbar Generator"""

    TITLE = "AXI Crossbar Top Level Generator"
    SUBTITLE = "Generate customized AXI4/AXI4-Lite crossbar top modules"
    CSS_PATH = os.path.join(SCRIPTDIR, "tui.css")

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("escape", "quit", "Quit"),
        ("b", "back", "Go Back"),
    ]

    SCREENS = {
        "global": GlobalSettingsScreen,
        "masters": MastersScreen,
        "slaves": SlavesScreen,
        "generate": GenerateScreen,
    }

    def __init__(self, output=None):
        super().__init__()
        # Initialize with default config
        global config
        config = AXIConfig()

        if output:
            config.global_config["OUTPUT_FILE"] = output

    def compose(self) -> ComposeResult:
        yield Header()
        yield Footer()

    def on_ready(self) -> None:
        """When app is ready, switch to protocol screen"""
        self.push_screen("global")

    def on_key(self, event) -> None:
        """Handle key bindings"""
        if event.key == "b":
            # Go back to previous screen
            if len(self.screen_stack) > 1:
                self.switch_screen(self.screen_stack[-2])



def main():
    """ Main """

    parser = argparse.ArgumentParser(
        description="TUI Interface for AXI Crossbar Top Level Generator"
    )

    parser.add_argument(
        "-o", "--output",
        default="config.json",
        help="Output config name (default: config.json)"
    )

    args = parser.parse_args()

    app = AXICrossbarTUI(args.output)
    app.run()


if __name__ == "__main__":
    main()
