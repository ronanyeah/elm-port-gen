declare module "*.elm" {
  const elm: {
    init: (options: {
      node: HTMLElement;
      flags: import("./ports").Flags;
    }) => import("./ports").ElmApp;
  };
  export default elm;
}
