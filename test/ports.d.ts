/* This file was generated by github.com/ronanyeah/elm-port-gen */

interface ElmApp {
  ports: Ports;
}

interface Ports {
  stop: PortOut<null>;
  log: PortOut<string>;
  sendData: PortOut<Data>;
  callback: PortIn<null>;
  read: PortIn<string>;
  receiveData: PortIn<Data>;
}

interface PortOut<T> {
  subscribe: (_: (_: T) => void) => void;
}

interface PortIn<T> {
  send: (_: T) => void;
}

interface Data {
  name: string;
  amount: number;
}

export { ElmApp, Data };