import nap

type Config* = object
  editor*: string
  path*: string
  run*: bool

proc get_config*(): Config =
  let editor = use_arg(name="editor", kind="value", help="nano or vim", value="nano")
  let path = use_arg(name="path", kind="argument", help="Path to a script file")
  let run = use_arg(name="run", kind="flag", help="Run path automatically")
  parse_args(); Config(editor:editor.val, path:path.val, run:run.used)