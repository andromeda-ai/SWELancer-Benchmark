from __future__ import annotations

# Load environment before importing anything else
from dotenv import load_dotenv
load_dotenv()

import json
from swelancer import SWELancerEval 
import argparse
import nanoeval
from nanoeval.evaluation import EvalSpec, RunnerArgs
from nanoeval.examples._gpqa import GPQAEval
from nanoeval.recorder import dummy_recorder
from nanoeval.setup import nanoeval_entrypoint
from swelancer_agent import SimpleAgentSolver
import os
import time

def parse_args():
    parser = argparse.ArgumentParser(description='Run SWELancer evaluation')
    parser.add_argument('--issue_ids', nargs='*', type=str, help='List of ISSUE_IDs to evaluate. If not specified, all issues will be evaluated.')
    parser.add_argument('--custom_setting', type=str, help='A custom setting to pass to the agent')
    return parser.parse_args()

async def main() -> None:
    args = parse_args()
    taskset = args.issue_ids if args.issue_ids else []
    
    # Set environment variable for the session ID
    if len(taskset) != 1:
        raise ValueError("Only one task ID is supported for session_id")
    os.environ["SWELANCER_SESSION_ID"] = f"SWELancer - Task {taskset[0]}"
    
    max_attempts = 7
    for i in range(max_attempts):
        os.environ["SWELANCER_ATTEMPT"] = f"{i + 1}"
        print(f"Running {i}/{max_attempts} times")
        report = await nanoeval.run(
            EvalSpec(
                # taskset is a list of ISSUE_IDs you wish to evaluate (e.g., ["123", "456_789"])
                eval=SWELancerEval(
                    solver=SimpleAgentSolver(model="deepseek-reasoner"),
                    taskset=taskset
                ),
                runner=RunnerArgs(
                    concurrency=len(taskset),
                    experimental_use_multiprocessing=False,
                    enable_slackbot=False,
                    recorder=dummy_recorder(),
                    max_retries=1
                ),
            )
        )
        print("-->", report)

        if report['aggregations']['num_correct'] > 0:
            break
        else:
            print("No correct answers, retrying...")

if __name__ == "__main__":
    nanoeval_entrypoint(main())
