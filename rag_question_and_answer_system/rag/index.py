import os
import click

from pathlib import Path
from proton_driver import client

from .service import _embedding

timeplus_host = os.getenv("TIMEPLUS_HOST")
timeplus_user = os.getenv("TIMEPLUS_USER")
timeplus_password = os.getenv("TIMEPLUS_PASSWORD")

# default timeplus proton driver
c = client.Client(
    host=timeplus_host, port=8463, user=timeplus_user, password=timeplus_password
)

def read_files_from_path(folder_path, suffix):
    text_content = []
    for file_path in Path(folder_path).glob(f"*.{suffix}"):
        with file_path.open("r", encoding="utf-8") as file:
            text_content.append((file.read(), file_path))
    return text_content


class Indexer:
    def __init__(self, name, path):
        self._doc_path = path
        self._name = name

    def index(self):
        doc_texts = read_files_from_path(self._doc_path, "md")

        for i, content in enumerate(doc_texts):
            text = content[0]
            filename = os.path.basename(content[1])
            embedding = _embedding(input=text)

            print(f"embedding {embedding}\n")
            print(f"{i} {filename} documents read \n")

            metadata = {}
            metadata["filename"] = filename
            ret = c.execute(
                "INSERT INTO vector_store (name, text, vector, metadata) VALUES",
                [[self._name, text, embedding, metadata]],
            )
            print(f"insert result {ret}")


@click.command()
@click.option("--path", default="./timeplus_docs", help="the path of documents")
def index(path):
    print(f"index files from path {path}")
    i = Indexer("timeplus_doc", path)
    i.index()

if __name__ == '__main__':
    index()