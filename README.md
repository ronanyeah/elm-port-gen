# elm-port-gen

`elm-port-gen ./src/Ports.elm`

```bash
elm-port-gen() {
  SRC_PATH="$1"
  shift
  SRC_PATH="$SRC_PATH" EXEC_PATH="$PWD" npm --prefix ~/repos/elm-port-gen run gen
}
```
